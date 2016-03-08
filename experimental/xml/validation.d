
/*
*   --- WORK IN PROGRESS ---
*   --- DOES NOT COMPILE ---
*   ---  NOT DOCUMENTED  ---
*/

module experimental.xml.validation;

enum Errors
{
    MISSING_XML_DECLARATION,        // <?xml ?> as first tag
    MISSING_XML_VERSION,            // version attribute in <?xml ?>
    MISSING_DOCTYPE_DECLARATION,    // <!DOCTYPE > after <?xml ?>
    MISSING_TOP_ELEMENT,            // more than one top-level element after prolog
    COMMENT_ENDING_WITH_HYPHEN,     // comment ending with ---> (one extra hyphen)
    GT_IN_TEXT                      // '>' inside text element
    AMPERSAND_IN_TEXT               // '&' inside text element
}