
module jaypha.fixdb.build;

import jaypha.fixdb.dbdef;
import dyaml.all;
import std.exception;


/*************************************************************************
 *
 * Table Definition builders
 *
 *************************************************************************/

void build_table_def(ref TableDef table, Node source)
in
{
  assert(source.isMapping);
}
body
{
  if (source.containsKey("is_a"))
  {
    table.columns ~= ColumnDef
    (
      "id",
      null,
      ColumnDef.Type.Int,
      null,
      0,
      0,
      [],
      null,
      false,
      true,
      false
    );
    table.primary = ["id"];
  }
  else if (!source.containsKey("no_id"))
  {
    table.columns ~= ColumnDef
    (
      "id",
      null,
      ColumnDef.Type.Int,
      null,
      0,
      0,
      [],
      null,
      false,
      true,
      true
    );
    table.primary = ["id"];
  }

  foreach (string n,Node v; source)
  {
    switch (n)
    {
      case "old_name":
        table.old_name = v.as!string;
        break;
      case "engine":
        table.engine = v.as!string;
        break;
      case "charset":
        table.charset = v.as!string;
        break;
      case "has_a":
        table.has_a = extract_values(v);
        foreach(name;table.has_a)
        {
          auto def = ColumnDef();
          def.name = name~"_id";
          def.type = ColumnDef.Type.Int;
          def.unsigned =true;
          table.columns ~= def;
        }
        break;
      case "belongs_to":
        table.belongs_to = extract_values(v);
        foreach(name;table.belongs_to)
        {
          auto def = ColumnDef();
          def.name = name~"_id";
          def.type = ColumnDef.Type.Int;
          def.unsigned =true;
          table.columns ~= def;
        }
        break;
      case "has_many":
        table.has_many = extract_values(v);
        break;
      case "primary":
        table.primary = extract_values(v);
        break;
      default:
        break;
    }
  }
  extract_columns(table, source["columns"]);
  if (source.containsKey("indicies"))
    extract_indicies(table, source["indicies"]);
}

//--------------------------------------------------------------------------

void extract_columns(ref TableDef table, Node value)
in
{
  assert(value.isSequence);
}
body
{
  foreach (Node v; value)
  {
    enforce (v.isMapping());
    ColumnDef col_def;
    build_column_def(col_def,v);
    table.columns ~= col_def;
  }
}

//--------------------------------------------------------------------------

void extract_indicies(ref TableDef table, Node value)
in
{
  assert(value.isMapping);
}
body
{
  foreach (string n, Node v; value)
  {
    table.indicies[n] = IndexDef();
    table.indicies[n].name = n;
    if (v.isMapping())
      build_index_def(table.indicies[n],v);
    else
    {
      enforce(v.isNull());
      table.indicies[n].columns = [ n ];
    }
  }
}


/*************************************************************************
 *
 * Column Definition builders
 *
 *************************************************************************/

void build_column_def(ref ColumnDef column, Node source)
in
{
  assert(source.isMapping);
}
body
{
  foreach (string n, Node v; source)
  {
    switch (n)
    {
      case "name":
        column.name = v.as!string;
        break;
      case "type":
        extract_type(column, v.as!string);
        break;
      case "old_name":
        column.old_name = v.as!string;
        break;
      case "size":
        column.size = v.as!uint;
        break;
      case "scale":
        column.scale = v.as!uint;
        break;
      case "values":
        column.values = extract_values(v);
        break;
      case "default":
        column.default_value = v.as!string;
        break;
      case "nullable":
        column.nullable = true;
        break;
      case "unsigned":
        column.unsigned = true;
        break;
      case "table":
        break;
      default:
        throw new Exception("column trait "~n~" not supported");
    }
    
  }
}

//--------------------------------------------------------------------------

void extract_type(ref ColumnDef column, string type)
{
  switch (type)
  {
    case "boolean":
    case "bool":
      column.type = ColumnDef.Type.Bool;
      break;
    case "int":
      column.type = ColumnDef.Type.Int;
      break;
    case "uint":
      column.type = ColumnDef.Type.Int;
      column.unsigned =true;
      break;
    case "long":
      column.type = ColumnDef.Type.BigInt;
      break;
    case "ulong":
      column.type = ColumnDef.Type.BigInt;
      column.unsigned =true;
      break;
    case "decimal":
      column.type = ColumnDef.Type.Decimal;
      break;
    case "time":
      column.type = ColumnDef.Type.Time;
      break;
    case "date":
      column.type = ColumnDef.Type.Date;
      break;
    case "datetime":
      column.type = ColumnDef.Type.DateTime;
      break;
    case "timestamp":
      column.type = ColumnDef.Type.Timestamp;
      break;
    case "float":
      column.type = ColumnDef.Type.Float;
      break;
    case "double":
      column.type = ColumnDef.Type.Double;
      break;
    case "enum":
      column.type = ColumnDef.Type.Enum;
      break;
    case "foreign":
      column.type = ColumnDef.Type.Int;
      column.unsigned =true;
      break;
    case "string":
      column.type = ColumnDef.Type.String;
      break;
    case "text":
      column.type = ColumnDef.Type.Text;
      break;
    default:
      column.type = ColumnDef.Type.Custom;
      column.custom_type = type;
  }
}

//--------------------------------------------------------------------------

void extract_enum_values(ref ColumnDef column, Node values)
in
{
  assert(values.isSequence());
}
body
{
  foreach (Node v; values)
  {
    if (!v.isScalar)
    {
      throw new Exception("Enum values must be strings");
    }
    column.values ~= v.as!string();
  }
}

//--------------------------------------------------------------------------

string[] extract_values(Node values)
{
  string[] list;
  if (values.isScalar)
    list ~= values.as!string;
  else foreach (Node v; values)
  {
    if (!v.isScalar())
    {
      throw new Exception("Values must be strings");
    }
    list ~= v.as!string;
  }
  return list;
}

/*************************************************************************
 *
 * Index Definition builders
 *
 *************************************************************************/

void build_index_def(ref IndexDef index, Node source)
{
  if (source.containsKey("columns"))
    index.columns = extract_values(source["columns"]);
  else
    index.columns = [ index.name ];

  if (source.containsKey("fulltext"))
    index.fulltext = true;
  else if (source.containsKey("unique"))
    index.unique = true;
}

/*************************************************************************
 *
 * Function Definition builders
 *
 *************************************************************************/

import std.stdio;

void build_function_def(ref FunctionDef fn, Node source)
{
  enforce(source.containsKey("body"));

  if (source.containsKey("definer"))
    fn.definer = source["definer"].as!string;
  else
    fn.definer = "CURRENT_USER";

  if (source.containsKey("deterministic"))
    fn.deterministic = true;

  if (source.containsKey("no_sql"))
    fn.no_sql = true;

  if (source.containsKey("parameters"))
  {
    foreach (string n,Node v; source["parameters"])
    {
      auto def = ColumnDef();
      def.name = n;
      if (v.isMapping())
        build_column_def(def,v);
      else
        enforce(v.isNull());
      fn.parameters ~= def;
    }
  }

  if (source.containsKey("returns"))
    extract_type(fn.returns, source["returns"].as!string);
  else
    fn.returns.type = ColumnDef.Type.String;

  fn.fn_body = source["body"].as!string;
  //fn.def = list["def"].get_string();
}

/*************************************************************************
 *
 * View Definition builders
 *
 *************************************************************************/

void buildViewDef(ref ViewDef viewDef, Node source)
{
  if (source.containsKey("sql"))
  {
    viewDef.sql = source["sql"].as!string;
  }
  else
  {
    throw new Exception("Non sql view not yet supported"); // TODO
  }
}
