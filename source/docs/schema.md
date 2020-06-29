# Schema Evolution

The schema evolution in **Dflat** Follows exact with flatbuffers. The only exception is that you cannot add more primary keys or change primary key to a different property once it is selected. Otherwise, you are free to add or remove indexes, rename properties. Properties to be removed should be marked as `deprecated`, new properties should be appended to the end of the table, and you should never change the type of a property.

There is no need for versioning as long as you follow the schema evolution path. Because the schema is maintained by flatbuffers, not SQLite, there is no disk ops required for schema upgrade. Schema upgrade failures due to lack of disk space or prolonged schema upgrade time due to pathological cases won't be a thing with **Dflat**.
