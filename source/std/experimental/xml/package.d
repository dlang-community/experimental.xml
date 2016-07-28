/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   An xml processing library.
+
+   $(H Quick start)
+   The library offers a simple fluid interface to build an XML parsing chain:
+   ---
+   auto input = "your xml input here...";
+
+   // the following steps are all configurable
+   auto domBuilder =
+        chooseLexer!input  // instantiate the best lexer based on the type of input
+       .parser             // instantiate a parser on top of the lexer
+       .cursor             // instantiate a cursor on top of the parser
+       .domBuilder;        // and finally the DOM builder on top of the cursor
+
+   // the source is forwarded down the parsing chain and everything is initialized
+   domBuilder.setSource(input);
+
+   // recursively build the entire DOM tree
+   domBuilder.buildRecursive;
+
+   // enjoy the resulting Document object
+   auto dom = domBuilder.getDocument;
+   ---
+   Also available is a SAX parser:
+   ---
+   // don't bother about the type of a node: the library will do the right instantiations
+   static struct MyHandler(NodeType)
+   {
+       void onElementStart(ref NodeType node)
+       {
+           writeln(node.getName);
+       }
+   }
+
+   auto saxParser =
+        chooseLexer!input
+       .parser
+       .cursor
+       .saxParser!MyHandler;   // only this call changed from the previous example chain
+
+   saxParser.setSource(input);
+   saxParser.processDocument;  // this call triggers the actual work
+   ---
+   You may want to perform extra checks on the input, to guarantee correctness:
+   ---
+   // some very useful error handlers:
+   auto callback1 = (CursorError err)
+   {
+       if (err == CursorError.MISSING_XML_DECLARATION)
+           assert(0, "Missing XML declaration");
+       else
+           assert(0, "Invalid attributes syntax");
+   }
+   auto callback2 = (string s) { assert(0, "Invalid XML element name"); }
+   auto callback3 = (string s) { assert(0, "Invalid XML attribute name"); }
+
+   auto domBuilder =
+        chooseLexer!input
+       .parser
+       .cursor(callback1)                      // optional callback argument
+       .checkXMLNames(callback2, callback3)    // a validation layer on top of the cursor
+       .domBuilder;
+   ---
+   While DOM and SAX are simple, standardized APIs, you may want to directly use
+   the underlying Cursor API, which provides great control, flexibility and speed:
+   ---
+   // A function to inspect the entire document recursively, writing the kind of nodes encountered
+   void writeRecursive(T)(ref T cursor)
+   {
+       // cycle the current node and all its siblings
+       do
+       {
+           writeln(cursor.getKind);
+           // if the current node has children, inspect them recursively
+           if (cursor.enter)
+           {
+               writeRecursive(cursor);
+               cursor.exit;
+           }
+       }
+       while (cursor.next);
+   }
+
+   auto cursor =
+        chooseLexer!input
+       .parse
+       .cursor;                // this time we stop here
+
+   cursor.setSource(input);
+   writeRecursive(cursor);     // call our function
+   ---
+
+   $(H Library overview)
+   $(HH The parsing chain)
+   $(HH The cursor wrappers)
+   $(HH The DOM)
+   $(HH The writer API)
+
+   Macros:
+       H = <h2>$1</h2>
+       HH = <h3>$1</h3>
+
+   Authors:
+   Lodovico Giaretta
+
+   License:
+   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
+
+   Copyright:
+   Copyright Lodovico Giaretta 2016 --
+/

module std.experimental.xml;

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
        .cursor!(Yes.conflateCDATA)
        .checkXMLNames;
        
    cursor.setSource(xml);
        
    assert(cursor.getKind == XMLKind.DOCUMENT);
}