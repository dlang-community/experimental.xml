/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

module entityparser;

/++
+ Parses the doctype, stores translations of entities and performs entity
+ substitution. Currently works only with internal entities.
+/
struct EntityParser(StringType)
{
    private StringType[StringType] entities;
    
    /++ 
    + Parses the given doctype, adding all entity declarations to the ones
    + already known.
    ++/
    public void parseDoctype(StringType doctype)
    {
    }
    
    /++ Adds an entity to the ones known by this object +/
    public void addEntity(StringType name, StringType value)
    {
        entities[name] = value;
    }
    
    /++ Returns the given string, after perfoming entity substitution +/
    public StringType substitute(StringType original)
    {
        
    }
}