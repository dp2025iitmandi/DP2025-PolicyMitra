import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';

/// Widget for displaying translated text using static translations
class TranslatedText extends StatelessWidget {
  final String translationKey;
  final Map<String, String>? params;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  
  const TranslatedText(
    this.translationKey, {
    super.key,
    this.params,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });
  
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        return Text(
          languageService.translate(translationKey, params: params),
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}

/// Widget for displaying dynamically translated text (uses Gemini)
class DynamicTranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool forceTranslate;
  
  const DynamicTranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.forceTranslate = false,
  });
  
  @override
  State<DynamicTranslatedText> createState() => _DynamicTranslatedTextState();
}

class _DynamicTranslatedTextState extends State<DynamicTranslatedText> {
  String _displayText = '';
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _displayText = widget.text;
    _translateText();
  }
  
  @override
  void didUpdateWidget(DynamicTranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.forceTranslate != widget.forceTranslate) {
      _translateText();
    }
  }
  
  void _translateText() async {
    if (widget.text.isEmpty) {
      setState(() => _displayText = '');
      return;
    }
    
    final languageService = Provider.of<LanguageService>(context, listen: false);
    
    // If English, no translation needed
    if (languageService.isEnglish) {
      setState(() => _displayText = widget.text);
      return;
    }
    
    // Show loading or original text
    setState(() {
      _isLoading = true;
      _displayText = widget.text;
    });
    
    // Translate
    final translated = await languageService.translateText(
      widget.text,
      forceTranslate: widget.forceTranslate,
    );
    
    if (mounted) {
      setState(() {
        _displayText = translated;
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        // Re-translate when language changes
        if (languageService.currentLanguage != (languageService.isEnglish ? 'en' : 'hi')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _translateText();
          });
        }
        
        return _isLoading
            ? Opacity(
                opacity: 0.7,
                child: Text(
                  _displayText,
                  style: widget.style,
                  textAlign: widget.textAlign,
                  maxLines: widget.maxLines,
                  overflow: widget.overflow,
                ),
              )
            : Text(
                _displayText,
                style: widget.style,
                textAlign: widget.textAlign,
                maxLines: widget.maxLines,
                overflow: widget.overflow,
              );
      },
    );
  }
}

