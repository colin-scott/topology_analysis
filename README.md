Analysis tools for Internet topology.

### neo4j notes

[Neo4j](http://neo4j.com/) is a neat open source graph database. We're going
to try using it for our topology analysis. Main advantage: we get to write
[declarative queries](http://neo4j.com/docs/stable/cypher-query-lang.html) rather than
low-level code (building our own indexes, iterating, etc.)

We use the neo4j ruby gem to interface with the database via ruby scripts.

To install neo4j:
```
$ wget http://neo4j.com/artifact.php?name=neo4j-community-2.1.5-unix.tar.gz
$ tar -xzf neo4j-community-2.1.5-unix.tar.gz
$ cd neo4j-community-2.1.5/
$ sudo bin/neo4j start
# Point browser to http://localhost:7474
```

To install ruby gem:
```
$ sudo gem install neo4j-core --pre
```

Assumes you have Ruby1.9+ and Java 1.7+ installed.

TODO: write up notes on tuning the configuration of neo4j.
