import "dart:async";

import "package:mongo_dart/mongo_dart.dart";
import "package:rethinkdb_driver/rethinkdb_driver.dart";

Db m;
Rethinkdb r;
Connection rconn;

main(List<String> args) async {
  // Initialize MongoDB connection
  m = new Db("mongodb://localhost/pollist");
  await m.open();
  
  m.
  
  // Initialize RethinkDB connection
  r = new Rethinkdb();
  r.connect(db: "pollist", host: "logan.directcode.org");
}