/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

@nogc unittest
{
    import std.experimental.xml.interfaces: XMLKind;
    import std.experimental.xml.lexers;
    import std.experimental.xml.parser;
    import std.experimental.xml.cursor;
    import std.experimental.xml.validation;
    import std.typecons: Yes, No;
   
    SliceLexer!string lexer;
    auto parser = lexer.parse;
   
    string xml = q{
    <?xml encoding = "utf-8" ?>
    <aaa xmlns:myns="something">
        <myns:bbb myns:att='>'>
            <!-- lol -->
            Lots of Text!
            On multiple lines!
        </myns:bbb>
        <![CDATA[ Ciaone! ]]>
        <ccc/>
    </aaa>
    };
    
    auto cursor =
         chooseLexer!xml
        .parse!(No.preserveWhitespace)
        .cursor!(Yes.conflateCDATA, Yes.noGC)
        .checkXMLNames;
        
    cursor.setSource(xml);
        
    assert(cursor.getKind == XMLKind.DOCUMENT);
}