module jaypha.fixdb.literal;

import jaypha.fixdb.dbdef;

import jaypha.io.print;
import jaypha.algorithm;
import std.algorithm;

import std.array;

string literal(ref DatabaseDef database_def)
{
  auto w = appender!string;
  w.println("DatabaseDef\n(\n  [");
  w.println(database_def.tables.map!literal().join(",\n"));
  w.println("  ],");
  if (database_def.views.length)
    w.println("  [\n",database_def.views.map!literal().join(",\n"),"  ],");
  else
    w.println("  null,");

  if (database_def.functions.length)
    w.print("[",database_def.functions.meld!((a,b) => ("\""~a~"\":"~b.literal()))().join(","),"]");
  else
    w.print("null");
  w.print(")");
  return w.data;
}


string literal(ref TableDef table_def)
{
  auto w = appender!string;
  w.print("    TableDef\n    (\n      ");
  w.print(quote_str(table_def.name));
  w.print(",");
  w.print(quote_str(table_def.old_name));
  w.print(",");
  w.print(quote_str(table_def.engine));
  w.print(",");
  w.print(quote_str(table_def.charset));
  w.print(",");
  w.print(table_def.no_id);
  w.print(",");
  w.print(quote_str(table_def.is_a));
  w.print(",[");
  w.print(table_def.has_a.map!quote_str().join(","));
  w.print("],[");
  w.print(table_def.belongs_to.map!quote_str().join(","));
  w.print("],[");
  w.print(table_def.has_many.map!quote_str().join(","));
  w.print("],[");
  w.print(table_def.primary.map!quote_str().join(","));
  w.print("],\n      [ //columns\n        ");
  //w.print(table_def.columns.meld!((a,b) => ("\""~a~"\":"~b.literal()))().join(",\n        "));
  w.print(table_def.columns.map!literal().join(",\n        "));
  w.print("\n      ],\n");
  if (table_def.indicies.length)
    w.println("      [",table_def.indicies.meld!((a,b) => ("\""~a~"\":"~b.literal()))().join(","),"]");
  else
    w.println("      null");
  w.print("    )");
  return w.data;
}


string literal(ref ColumnDef column_def)
{
  auto w = appender!string;
  w.print("ColumnDef(");
  w.print(quote_str(column_def.name));
  w.print(",");
  w.print(quote_str(column_def.old_name));
  w.print(",");
  w.print("ColumnDef.Type.",column_def.type);
  w.print(",");
  w.print(quote_str(column_def.custom_type));
  w.print(",");
  w.print(column_def.size);
  w.print(",");
  w.print(column_def.scale);
  w.print(",[");
  w.print(column_def.values.map!quote_str().join(","));
  w.print("],");
  w.print(quote_str(column_def.default_value));
  w.print(",");
  w.print(column_def.nullable);
  w.print(",");
  w.print(column_def.unsigned);
  w.print(",");
  w.print(column_def.auto_increment);
  w.print(")");
  return w.data;
}

string literal(ref IndexDef index_def)
{
  auto w = appender!string;
  w.print("IndexDef(");
  w.print(quote_str(index_def.name)),
  w.print(",");
  w.print(index_def.unique);
  w.print(",");
  w.print(index_def.fulltext);
  w.print(",[");
  w.print(index_def.columns.map!quote_str().join(","));
  w.print("])");
  return w.data;
}

string literal(ref ViewDef viewDef)
{
  auto w = appender!string;
  w.print("    ViewDef\n    (\n      ");
  w.print(quote_str(viewDef.name));
  w.print(",\n      ");
  w.print(quote_str(viewDef.sql));
  w.print("\n    )");
  return w.data;
}

string literal(ref FunctionDef function_def)
{
  auto w = appender!string;
  w.print("FunctionDef(");
  w.print(quote_str(function_def.name));
  w.print(",");
  w.print(quote_str(function_def.definer));
  w.print(",");
  w.print(function_def.no_sql);
  w.print(",");
  w.print(function_def.deterministic);
  w.print(",[");
  w.print(function_def.parameters.map!literal().join(","));
  w.print("],");
  w.print(literal(function_def.returns));
  w.print(",");
  w.print(quote_str(function_def.fn_body));
  w.print(")");
  return w.data;
}

string quote_str(string s)
{
  if (s is null)
    return "null";
  else
    return "\""~s~"\"";
}
