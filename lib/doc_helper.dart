import 'package:flutter/widgets.dart';
import 'package:googleapis/docs/v1.dart' as docs;

extension DocExtension on docs.Document {

  docs.Body get _body => body ??= docs.Body(content: []);

  docs.Paragraph get lastParagraph => _body.content!.isEmpty ? addParagraph() : _body.content!.last.paragraph!;

  docs.Paragraph addParagraph([docs.Paragraph? paragraph]) {
    paragraph ??= docs.Paragraph(elements: []);
    _body.content!.add(
        docs.StructuralElement(
            paragraph: paragraph
        )
    );
    return paragraph;
  }

  List<docs.ParagraphElement> addParagraphElements(List<docs.ParagraphElement> elements) {
    lastParagraph.elements!.addAll(elements);
    return elements;
  }

  docs.TextRun addTextRun(docs.TextRun textRun, {newParagraph = false}) {
    if (newParagraph) {
      addParagraph();
    }
    addParagraphElements([
      docs.ParagraphElement(
        textRun: textRun,
      )
    ]);
    return textRun;
  }

  docs.TextRun addText(String text, TextStyle? style, {newParagraph = false}) {
    return addTextRun(docs.TextRun(
        content: text,
        textStyle: docs.TextStyle(
          foregroundColor: style?.color == null ? null : docs.OptionalColor(
              color: docs.Color(
                  rgbColor: docs.RgbColor(
                    red: style!.color!.red/255.0,
                    green: style.color!.green/255.0,
                    blue: style.color!.blue/255.0,
                  )
              )
          ),
          backgroundColor: style?.backgroundColor == null ? null : docs.OptionalColor(
              color: docs.Color(
                  rgbColor: docs.RgbColor(
                    red: style!.backgroundColor!.red/255.0,
                    green: style.backgroundColor!.green/255.0,
                    blue: style.backgroundColor!.blue/255.0,
                  )
              )
          ),
          fontSize: style?.fontSize == null ? null : docs.Dimension(
              magnitude: style!.fontSize
          ),
          bold: style?.fontWeight == FontWeight.bold,
          italic: style?.fontStyle == FontStyle.italic,
          // weightedFontFamily:
        )
    ),
        newParagraph: newParagraph
    );
  }
}