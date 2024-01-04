import SwiftSoup
import Foundation

public class BasicHTML: HTML {
    public var rawHTML: String
    public var document: Document?
    public var rawText: String = ""
    public var markdown: String = ""
    var hasSpacedParagraph: Bool = false
    
    public required init() {
        rawHTML = "Document not initialized correctly"
    }

    /// Converts the given node into valid Markdown by appending it onto the ``MastodonHTML/markdown`` property.
    /// - Parameter node: The node to convert
    public func convertNode(_ node: Node) throws {
        if node.nodeName().starts(with: "h") {
            guard let last = node.nodeName().last else {
                return
            }
            guard let level = Int(String(last)) else {
                return
            }
            
            markdown += "\n"
            for _ in 0..<level {
                markdown += "#"
            }
            
            markdown += " "
            
            for node in node.getChildNodes() {
                try convertNode(node)
            }
            
            markdown += "\n\n"
            
            return
        } else if node.nodeName() == "p" {
            if !markdown.isEmpty { // Ignore anything at the beginning of the document
                if hasSpacedParagraph {
                    markdown += "\n\n"
                } else {
                    hasSpacedParagraph = true
                }
            }
            
            for node in node.getChildNodes() {
                try convertNode(node)
            }
            
            markdown += "\n\n"
            
            return
        } else if node.nodeName() == "br" {
            if !markdown.isEmpty { // Ignore anything at the beginning of the document
                markdown += "  \n"
            }
        } else if node.nodeName() == "a" {
            markdown += "["
            for child in node.getChildNodes() {
                try convertNode(child)
            }
            markdown += "]"

            let href = try node.attr("href")
            markdown += "(\(href))"
            return
        } else if node.nodeName() == "strong" || node.nodeName() == "b" {
            markdown += "**"
            for child in node.getChildNodes() {
                try convertNode(child)
            }
            markdown += "**"
            
            // Handle situations with non-breaking spaces after text within strong tags
            if let lastChild = node.getChildNodes().last {
                if lastChild.nodeName() == "#text" && lastChild.description == "&nbsp;" {
                    /// <strong><a href="https://" target="_blank" rel="noreferrer noopener">CLICK here</a>&nbsp;</strong>
                    markdown += " "
                } else if let lastChildNode = lastChild.getChildNodes().last, lastChildNode.description.hasSuffix("&nbsp;") {
                    /// <strong><a href="https://www.worldhope.org.au/">Click here&nbsp;</a></strong>
                    markdown += " "
                }
            }
            return
        } else if node.nodeName() == "em" || node.nodeName() == "i" {
            markdown += "*"
            for child in node.getChildNodes() {
                try convertNode(child)
            }
            markdown += "*"
            return
        } else if node.nodeName() == "s" {
            markdown += "~~"
            for child in node.getChildNodes() {
                try convertNode(child)
            }
            markdown += "~~"
            return
        } else if node.nodeName() == "code" {
            markdown += "`"
            for child in node.getChildNodes() {
                try convertNode(child)
            }
            markdown += "`"
            return
        } else if node.nodeName() == "pre", node.childNodeSize() >= 1 {
            if hasSpacedParagraph {
                markdown += "\n\n"
            } else {
                hasSpacedParagraph = true
            }

            let codeNode = node.childNode(0)
            
            if codeNode.nodeName() == "code" {
                markdown += "```"
                
                // Try and get the language from the code block

                if let codeClass = try? codeNode.attr("class"),
                   let language = codeClass.regex(pattern: #"lang.*-(\w+)"#).first {
                   //let match = try? #/lang.*-(\w+)/#.firstMatch(in: codeClass) {
                    // match.output.1 is equal to the second capture group.
                    //let language = match.output.1
                    markdown += language + "\n"
                } else {
                    // Add the ending newline that we need to format this correctly.
                    markdown += "\n"
                }
                
                for child in codeNode.getChildNodes() {
                    try convertNode(child)
                }
                markdown += "\n```"
                return
            }
        } else if node.nodeName() == "ul" || node.nodeName() == "ol" {
            // Add support for lists
            let listItemTag = node.nodeName() == "ul" ? "*" : "1."
            for child in node.getChildNodes() where child.nodeName() == "li" {
                markdown += "\n\(listItemTag) "
                for node in child.getChildNodes() {
                    try convertNode(node)
                }
            }
            markdown += "\n"
            return
        }

        if node.nodeName() == "#text" {
            var result = node.description
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(
                    of: " {2,}",
                    with: " ",
                    options: .regularExpression,
                    range: nil)
            
            // We need to trim whitespaces within content if wrapped with certain markdown elements:
            // eg: **Hello World ** or [Link here ](https://google.com) so we need to know the parent?
            if ["b", "strong", "em", "i", "a", "s"].contains(node.parent()?.nodeName()) {
                result = result.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            markdown += result
        }

        for node in node.getChildNodes() {
            try convertNode(node)
        }
    }

}

extension String {
    func regex(pattern: String, options: NSRegularExpression.Options = [.dotMatchesLineSeparators]) -> [String] {
        do {
            let string = self as NSString
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let range = NSRange(location: 0, length: string.length)
            let matches = regex.matches(in: self, range: range)
            return matches.map { string.substring(with: $0.range) }
        } catch {
            return []
        }
    }
}
