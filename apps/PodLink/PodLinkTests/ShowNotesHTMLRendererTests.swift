import Foundation
import Testing
import UIKit
@testable import PodLink

@MainActor
struct ShowNotesHTMLRendererTests {

    /// Flattens a rendered string so runs can be compared as text: `¶` is a
    /// paragraph break, `↵` a soft line break, and `[BI@url:text]` a run that
    /// is bold, italic, or linked.
    private func describe(_ html: String) -> String {
        let rendered = ShowNotesHTMLRenderer.render(html, pointSize: 15)
        var out = ""
        let full = NSRange(location: 0, length: rendered.length)
        rendered.enumerateAttributes(in: full, options: []) { attributes, range, _ in
            let text = (rendered.string as NSString).substring(with: range)
                .replacingOccurrences(of: "\n", with: "¶")
                .replacingOccurrences(of: "\u{2028}", with: "↵")
            var flags = ""
            if let font = attributes[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.traitBold) { flags += "B" }
                if traits.contains(.traitItalic) { flags += "I" }
            }
            if let url = attributes[.link] as? URL {
                flags += "@" + url.absoluteString
            }
            out += flags.isEmpty ? text : "[\(flags):\(text)]"
        }
        return out
    }

    @Test
    func separatesParagraphs() {
        #expect(describe("<p>Hello <b>world</b></p><p>Next</p>") == "Hello [B:world]¶Next")
        #expect(describe("<p>One</p>\n\n<p>Two</p>\n") == "One¶Two")
        #expect(describe("<div><div><p>Nested</p></div></div><div>Sibling</div>") == "Nested¶Sibling")
        #expect(describe("<p>  spaced   <i>out</i>   text  </p>  ") == "spaced [I:out] text")
    }

    @Test
    func keepsSoftLineBreaksWithoutStackingThem() {
        #expect(describe("Timestamps:<br>00:00 Intro<br>05:30 Topic") == "Timestamps:↵00:00 Intro↵05:30 Topic")
        #expect(describe("Intro<br>Two<br/><br /><br>Three") == "Intro↵Two↵↵Three")
        #expect(describe("<p>One<br/><br/></p><p><br></p><p>Two</p>") == "One¶Two")
    }

    @Test
    func keepsLinks() {
        #expect(
            describe(#"See <a href="https://example.com/a?x=1&amp;y=2">the <em>site</em></a> now."#)
                == "See [@https://example.com/a?x=1&y=2:the ][I@https://example.com/a?x=1&y=2:site] now."
        )
        #expect(
            describe("<a href='https://a.b'>single</a> <a href=https://c.d>bare</a>")
                == "[@https://a.b:single] [@https://c.d:bare]"
        )
        #expect(describe(#"<a href="">empty</a> <a>none</a> x"#) == "empty none x")
    }

    @Test
    func rendersLists() {
        #expect(
            describe("<ul><li>One</li><li>Two</li></ul><ol><li>A</li><li>B</li></ol>After")
                == "• One¶• Two¶1. A¶2. B¶After"
        )
        #expect(
            describe("<ol><li><p>First</p></li><li><p>Second</p><p>More</p></li></ol>")
                == "1. First¶2. Second¶More"
        )
        #expect(
            describe("<ul>\n  <li><strong>Bold</strong> item</li>\n  <li>Plain</li>\n</ul>")
                == "• [B:Bold] item¶• Plain"
        )
        #expect(
            describe("<ul><li>Outer<ul><li>Inner</li></ul></li><li>Next</li></ul>")
                == "• Outer¶\u{2003}• Inner¶• Next"
        )
    }

    @Test
    func decodesEntities() {
        #expect(
            describe("<h2>Title</h2><p>Fish &amp; chips &lt;tag&gt; &#8217;q&#x2019; caf&eacute;</p>")
                == "[B:Title]¶Fish & chips <tag> \u{2019}q\u{2019} caf\u{00E9}"
        )
        #expect(describe("<p>emoji &#128512; &#x1F600;</p>") == "emoji \u{1F600} \u{1F600}")
        #expect(describe("<p>bad &#99999999; &#xD800; &unknown; ent</p>") == "bad &#99999999; &#xD800; &unknown; ent")
    }

    @Test
    func dropsMarkupThatIsNotContent() {
        #expect(describe("<!-- c --><style>p{}</style><script>x<y</script><p>Kept</p>") == "Kept")
        #expect(describe("</b></a>stray <unknown attr=1>tags</unknown>") == "stray tags")
        #expect(describe("<p></p><div> </div>") == "")
        #expect(describe("5 < 6 and a<b>bold</b>") == "5 < 6 and a[B:bold]")
    }

    @Test
    func showNotesKeepLinksAndText() {
        let notes = ShowNotesFormattedContent.attributedString(
            from: #"<p>Read <a href="https://example.com/post">the post</a>.</p><p>Thanks</p>"#,
            linkUIColor: .systemBlue
        )
        #expect(String(notes.characters) == "Read the post.\nThanks")
        #expect(notes.runs.contains { $0.link == URL(string: "https://example.com/post") })
    }
}
