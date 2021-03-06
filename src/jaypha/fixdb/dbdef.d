
module jaypha.fixdb.dbdef;

//--------------------------------
struct DatabaseDef
//--------------------------------
{
  TableDef[] tables;
  ViewDef[] views;
  FunctionDef[string] functions;
}

//--------------------------------
struct TableDef
//--------------------------------
{
  string name;
  string old_name;

  string engine;
  string charset;

  bool no_id;

  string is_a;
  string[] has_a;
  string[] belongs_to;
  string[] has_many;

  string[] primary;

  ColumnDef[] columns;
  IndexDef[string] indicies;
}

//--------------------------------
struct ColumnDef
//--------------------------------
{
  enum Type { Bool, Int, BigInt, Decimal, String, Text, Time, Date, DateTime, Timestamp, Float, Double, Enum, Custom };

  string name;
  string old_name;

  Type type = Type.String;
  string custom_type;

  uint size;  // for char array and decimal
  uint scale; // decimal places
  string[] values; // for enums

  string default_value = null;

  bool nullable;
  bool unsigned;
  bool auto_increment;
}

//--------------------------------
struct IndexDef
//--------------------------------
{
  string name;
  bool unique;
  bool fulltext;
  string[] columns;
}

//--------------------------------
struct FunctionDef
//--------------------------------
{
  string name;
  string definer;
  bool no_sql = false;
  bool deterministic = false;

  ColumnDef[] parameters;
  ColumnDef returns;
  string fn_body;

  //string def;
}

//--------------------------------
struct ViewDef
//--------------------------------
{
  string name;
  string sql;
  string[][string] columns;  // table, columns
  string[string][string] aliases;  // table, column, alias
  string[string] joins;
}

