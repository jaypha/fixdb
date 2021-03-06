

module jaypha.fixdb.fixdb_mysql;

import jaypha.types;

import jaypha.fixdb.dbdef;

import jaypha.dbsql.mysql.database;

import jaypha.properties;

public import std.stdio;
import std.getopt;
import std.exception;
import std.algorithm;
import std.array;
import std.conv;
import std.string;
import std.file;

//-----------------------------------------------------------------------------

alias MySqlDatabase DB;

bool quiet, dry_run, no_backup, show_sql, help;

enum id_column_def = "`id` int(11) unsigned not null auto_increment";

//-----------------------------------------------------------------------------

string[] getTables(DB database)
{
  string[] tables;
  
  foreach (r;database.query("show full tables"))
  {
    if (r["Table_type"] != "VIEW")
      tables ~= r["Tables_in_"~database.dbname];
  }
  return tables;
}

string[] getViews(DB database)
{
  string[] views;
  
  foreach (r;database.query("show full tables"))
  {
    if (r["Table_type"] == "VIEW")
      views ~= r["Tables_in_"~database.dbname];
  }
  return views;
}

//-----------------------------------------------------------------------------

DatabaseDef database_def;

void function(DB db, bool, bool, bool) post_db_make;

//-----------------------------------------------------------------------------

bool isSame(S = string)(S a, S b)
{
  if (a is null && b is null)
    return true;
  if (a is null || b is null)
    return false;
  return (a == b);
}

//-----------------------------------------------------------------------------

void main(string[] args)
{
  string fileName;

  getopt
  (
    args,
    "q", &quiet,
    "d", &dry_run,
    "n", &no_backup,
    "s", &show_sql,
    "h", &help,
    "c", &fileName
  );

  if (help) { printFormat(true); return; }
  if (fileName is null) { printFormat(); return; }

  strstr settings = extractProperties(cast(string) readText!string(fileName));

  enforce("database.hostname" in settings);
  enforce("database.database" in settings);
  enforce("database.username" in settings);

  auto db = new DB();
  db.host = settings["database.hostname"];
  db.dbname =  settings["database.database"];
  db.username = settings["database.username"];
  if ("database.password" in settings)
    db.password = settings["database.password"];

  auto queries = getQueries(database_def, db);

  foreach (query; queries)
  {
    if (query)
    {
      if (show_sql) { writeln(query); writeln("------------------"); }
      if (!dry_run) { db.query(query); }
    }
  }

  if (!quiet) writeln("Running post db make.");
  if (post_db_make !is null)
    post_db_make(db, quiet, dry_run, show_sql);
}

//-----------------------------------------------------------------------------

string[] getQueries(ref DatabaseDef def, DB db)
{
  string[] vtNames;
  string[] old_names;

  auto queries = appender!(string[])();

  //-----------------------------------
  // Fix tables
  
  foreach (table; def.tables)
  {
    vtNames ~= table.name;
    if (table.old_name)
      old_names ~= table.old_name;
    queries.put(get_fix_table_query(table, db));
  }

  // Remove any table not in the definition list, but tables in the 'oldNames'
  // list have been renamed so we don't need to remove them.

  string[] tv = getTables(db);
  foreach(t;tv)
  {
    if
    (
      find(vtNames,t).empty &&
      find(old_names,t).empty
    )
    {
      if (!quiet) writeln("Removing table '",t,"'");
      queries.put("drop table `"~t~"`");
    }
  }

  //-----------------------------------
  // Fix views

  vtNames.length = 0;

  foreach (view; def.views)
  {
    vtNames ~= view.name;
    queries.put("drop view if exists `"~view.name~"`");
    queries.put(getFixViewQuery(view, db));
  }

  tv = getViews(db);
  foreach(t;tv)
  {
    if (find(vtNames,t).empty)
    {
      if (!quiet) writeln("Removing view '",t,"'");
      queries.put("drop view `"~t~"`");
    }
  }

  //-----------------------------------
  // Regenerate functions.

  foreach (n, fn; def.functions)
  {
    if (!quiet) writeln("Creating function '"~n~"'");
    queries.put("drop function if exists `"~n~"`");
    queries.put(get_function_def_sql(fn, db));
  }

  return queries.data;
}

//-----------------------------------------------------------------------------
// SQL for fixing a single table.

string get_fix_table_query(ref TableDef def, DB db)
{
  if (def.old_name && db.tableExists(def.old_name))
  {
    if (db.tableExists(def.name))
    {
      throw new Exception("Cannot rename table '"~def.old_name~"' to '"~def.name~"', table already exists.");
    }
    auto old_table = extract_table(def.old_name, db);
    return get_alter_table_sql(def, old_table, db);
  }
  else
  {
    if (!db.tableExists(def.name))
    {
      if (!quiet) writeln("Creating table '"~def.name~"'");
      return get_create_table_sql(def, db);
    }
    else
    {
      auto old_table = extract_table(def.name, db);
      auto s = get_alter_table_sql(def, old_table, db);

      if (s && !quiet) writeln("altering "~def.name);
      return s;
    }
    return null;
  }
}

//-----------------------------------------------------------------------------
//
// SQL Generator functions
//
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Table creation

string get_create_table_sql(ref TableDef def, DB db)
{
  auto items = appender!(string[])();
  string primary;
  string engine = (def.engine)?def.engine:"innodb";
  string charset = (def.charset)?def.charset:"utf8";

  //if (!def.no_id)
  //{
  //  primary = "id";
  //  items.put(id_column_def);
  //}
  //else
  if (def.primary.length)
    primary = def.primary.join("`,`");
  
  foreach (column; def.columns)
  {
    items.put(get_column_sql(column, db));
  }

  if (primary.length)
    items.put("primary key(`"~primary~"`)");

  foreach (name, index; def.indicies)
    items.put(get_index_sql(index, db));

  return join
  (
    [
      "create table `",def.name,"` (",
      items.data.join(","),
      ") engine=",engine," default charset=",charset,";"
    ]
  );
}

//-----------------------------------------------------------------------------
// Column type

string get_type_sql(ref ColumnDef def, DB db)
{
  string s;
  final switch (def.type)
  {
    case ColumnDef.Type.Bool:
      s ="tinyint(1)";
      break;
    case ColumnDef.Type.Int:
      s = "int(11)";
      break;
    case ColumnDef.Type.BigInt:
      s ="bigint(20)";
      break;
    case ColumnDef.Type.Decimal:
      s = "decimal("~to!string(def.size)~","~to!string(def.scale)~")";
      break;
    case ColumnDef.Type.Time:
      s ="time";
      break;
    case ColumnDef.Type.Date:
      s ="date";
      break;
    case ColumnDef.Type.DateTime:
      s ="datetime";
      break;
    case ColumnDef.Type.Timestamp:
      s ="timestamp";
      break;
    case ColumnDef.Type.String:
      if (def.size)
      {
        enforce(def.size <= 255);
        s ="char("~to!string(def.size)~")";
      }
      else s ="varchar(255)";
      break;
    case ColumnDef.Type.Text:
      s ="text";
      break;
    case ColumnDef.Type.Float:
      s ="double"; // MySQL does all calculations in double.
      break;
    case ColumnDef.Type.Double:
      s ="double";
      break;
    case ColumnDef.Type.Enum:
      s ="enum("~def.values.map!(a => db.quote(a))().join(",")~")";
      break;
    case ColumnDef.Type.Custom:
      s = def.custom_type;
      break;
  }

  if (def.unsigned)
    s ~= " unsigned";

  return s;
}

//-----------------------------------------------------------------------------
// Column creation

string get_column_sql(ref ColumnDef column_def, DB db)
{
  auto s = appender!string();
  
  s.put("`");
  s.put(column_def.name);
  s.put("` ");

  s.put(get_type_sql(column_def,db));

  if (column_def.nullable)
    s.put(" null");
  else
    s.put(" not null");

  if (column_def.auto_increment)
    s.put(" auto_increment");

  if (column_def.default_value)
  {
    s.put(" default ");
    if
    (
      column_def.type == ColumnDef.Type.Timestamp &&
      (column_def.default_value == "0" || column_def.default_value == "CURRENT_TIMESTAMP")
    )
    {
      s.put(column_def.default_value);
    }
    else
      s.put(db.quote(column_def.default_value));
  }

  return s.data;
}

//-----------------------------------------------------------------------------
// Index creation

string get_index_sql(ref IndexDef index_def, DB db)
{
  string s;

  if (index_def.fulltext)
    s = "fulltext ";
  else if (index_def.unique)
    s = "unique ";

  s ~= "index `"~index_def.name~"` (`"~index_def.columns.join("`,`")~"`)";
  
  return s;
}

//-----------------------------------------------------------------------------
// Alter table

string get_alter_table_sql
(
  ref TableDef new_def, ref TableDef old_def, DB db
)
{
  string[] s;
  string[] d; // For drops, which need to be done first.

  string[] names;

  auto original_name = old_def.name;

  if (!quiet) writeln("Altering table '"~original_name~"'");

  if (old_def.name != new_def.name)
  {
    if (!quiet) writeln("  Rename to " ~ new_def.name);
    s ~= ("rename to "~new_def.name);
  }

  //-----------------------------------
  // Columns

  // Go through column definitions. Add new columns and alter existing ones if
  // different.

  ulong[string] new_names, old_names;

  foreach (i,column_def; new_def.columns)
    new_names[column_def.name] = i;
  foreach (i,column_def; old_def.columns)
    old_names[column_def.name] = i;
    
  foreach (column_def; new_def.columns)
  {
    auto name = column_def.name;
    if (column_def.old_name && column_def.old_name in old_names)
    {
      // Column is being renamed, must redefine.
      if (name in old_names)
        throw new Exception("oldname and new name both exist");

      names ~= column_def.old_name;
      if (!quiet) writeln("  rename column '"~column_def.old_name~"' to '"~name~"'");
      s ~= 
      (
        format
        (
          "change `%s` %s",
          column_def.old_name,
          get_column_sql(column_def, db)
        )
      );
    }
    else if (name in old_names)
    {
      // Column of same name exists, so alter if different.

      names ~= name;
      bool change = false;
      string type = get_type_sql(column_def, db);
      
      auto old_cdef = old_def.columns[old_names[name]];

      if (type != old_cdef.custom_type)
        change = true;
      if (!(isSame(column_def.default_value,old_cdef.default_value)))
        change = true;
      if (column_def.nullable != old_cdef.nullable)
        change = true;
      if (column_def.auto_increment != old_cdef.auto_increment)
        change = true;

      if (change)
      {
        if (!quiet) writeln("  modify column '"~name~"'");
        s ~= ("modify "~get_column_sql(column_def, db));
      }
    }
    else
    {
      // New Column

      if (!quiet) writeln("  adding column '"~name~"'");
      s ~= ("add column "~get_column_sql(column_def, db));
    }
  }

  // Go through existing columns and remove columns not in the new definition.
  foreach (column_def; old_def.columns)
  {
    auto name = column_def.name;

    if (find(names,name).empty) 
    {
      if (!quiet) writeln("  removing "~name);
      d ~= ("drop column `"~name~"`");
    }
  }

  //-----------------------------------
  // Indicies

  bool has_primary = false;
  foreach (name,idx; old_def.indicies)
  {
    if (name != "PRIMARY")
    {
      // Drop index if not in new def.

      if (!(name in new_def.indicies))
      {
        if (!quiet) writeln(format("  drop index '%s'",name));
        d ~= (format("drop index `%s`", name));
      }
    }
  }

  if (old_def.primary != new_def.primary)
  {
    if (old_def.primary.length)
    {
      if (!quiet) writeln("  drop primary key ",old_def.primary);
      d ~= ("drop primary key");
    }
    if (new_def.primary.length)
    {
      if (!quiet) writeln("  add primary key '"~new_def.primary.join("','")~"'");
      s ~= ("add primary key (`"~new_def.primary.join("`,`")~"`)");
    }
  }

  foreach (name,idx; new_def.indicies)
  {
    if (!(name in old_def.indicies))
    {
      if (!quiet) writeln(format("  add index '%s'",name));
      s ~= ("add " ~ get_index_sql(idx, db));
    }
    else
    {
      if
      (
        idx.columns != old_def.indicies[name].columns ||
        idx.unique != old_def.indicies[name].unique ||
        idx.fulltext != old_def.indicies[name].fulltext
      )
      {
        if (!quiet) writeln(format("  altering index '%s'",name));
        d ~= ("drop index `"~name~"`");
        s ~= ("add "~get_index_sql(idx,db));
      }
    }
  }

  auto items = d ~ s;

  if (items.length)
    return format("alter table `%s` %s",old_def.name, join(items, ","));
  else
  {
    if (!quiet) writeln("  no alterations");
    return null;
  }
}

//-----------------------------------------------------------------------------
// Views

string getFixViewQuery(ref ViewDef viewDef, DB db)
{
  auto s = appender!string();
  s.put("CREATE VIEW `"~viewDef.name~"` as ");
  s.put(viewDef.sql);
  return s.data;
}

//-----------------------------------------------------------------------------
// Functions

string get_function_def_sql(ref FunctionDef fn, DB db)
{
  auto s = appender!string();
  string[] parms;

  s.put("CREATE DEFINER = ");
  s.put(fn.definer);
  s.put(" FUNCTION `");
  s.put(fn.name);
  s.put("`(");
  foreach (v; fn.parameters)
  {
    auto p = appender!string();

    p.put("`");
    p.put(v.name);
    p.put("` ");
    p.put(get_type_sql(v, db));
    parms ~= p.data;
  }
  if (parms.length)
    s.put(parms.join(","));

  s.put(") RETURNS ");
  s.put(get_type_sql(fn.returns, db));
  if (fn.no_sql)
    s.put(" NO SQL");
  if (fn.deterministic)
    s.put(" DETERMINISTIC");
  s.put(" BEGIN ");
  s.put(fn.fn_body);
  s.put(" END;");

  return s.data;
}

//-----------------------------------------------------------------------------
//
// Database extraction
//
//-----------------------------------------------------------------------------

TableDef extract_table(string name, DB db)
{
  TableDef table;
  table.name = name;
  strstr[] data = db.queryData("show columns from `"~name~"`");
  foreach (row; data)
  {
    ColumnDef column_def;

    column_def.name = row["Field"];
    column_def.old_name = null;
    column_def.default_value = row["Default"];
    column_def.custom_type = row["Type"];
    column_def.nullable = (row["Null"] == "YES");
    column_def.auto_increment = (row["Extra"] == "auto_increment");
    
    table.columns ~= column_def;
  }
  
  data = db.queryData("show index from `"~name~"`");

  foreach (row; data)
  {
    string iname = row["Key_name"];
    if (iname == "PRIMARY")
      table.primary ~= row["Column_name"];

    else if (row["Seq_in_index"] == "1")
    {
      IndexDef def;
      def.columns ~= row["Column_name"];
      def.unique = row["Non_unique"] == "0";
      def.fulltext = row["Index_type"] == "FULLTEXT";
      
      table.indicies[iname] = def;
    }
    else
    {
      table.indicies[iname].columns ~= row["Column_name"];
    }
  }
  
  return table;
}

//-----------------------------------------------------------------------------

void printFormat(bool verbose = false)
{
  writeln("Format: fixdb [-q] [-d] [-n] [-h] [-s] -c<config_path>");
  
  if (verbose)
  {
    writeln("options: -q - quiet mode (overrides -s)");
    writeln("         -d - dry run, implies -n");
    writeln("         -n - No backup");
    writeln("         -s - show SQL");
    writeln("         -h - print usage");
    writeln("         -c<config_path> path to config file containing connection details");
  }
}

//-----------------------------------------------------------------------------

