import 'package:flutter/material.dart';

class OverflowMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final Alignment alignment;
  final Duration startPause;
  final Duration endPause;
  final Duration returnDuration;
  final double speedPixelsPerSecond;

  const OverflowMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.left,
    this.alignment = Alignment.centerLeft,
    this.startPause = const Duration(milliseconds: 800),
    this.endPause = const Duration(milliseconds: 600),
    this.returnDuration = const Duration(milliseconds: 700),
    this.speedPixelsPerSecond = 36,
  });

  @override
  State<OverflowMarqueeText> createState() => _OverflowMarqueeTextState();
}

class _OverflowMarqueeTextState extends State<OverflowMarqueeText> {
  final ScrollController _scrollController = ScrollController();
  int _loopToken = 0;
  bool _postFrameQueued = false;

  @override
  void initState() {
    super.initState();
    _queueCheck();
  }

  @override
  void didUpdateWidget(covariant OverflowMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.textAlign != widget.textAlign ||
        oldWidget.alignment != widget.alignment) {
      _queueCheck();
    }
  }

  @override
  void dispose() {
    _loopToken++;
    _scrollController.dispose();
    super.dispose();
  }

  void _queueCheck() {
    if (_postFrameQueued) {
      return;
    }
    _postFrameQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postFrameQueued = false;
      _restartLoop();
    });
  }

  void _restartLoop() {
    _loopToken++;
    final token = _loopToken;
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.maxScrollExtent <= 0) {
      if (_scrollController.offset > 0) {
        _scrollController.jumpTo(0);
      }
      return;
    }
    _runLoop(token);
  }

  Future<void> _runLoop(int token) async {
    while (mounted && token == _loopToken) {
      if (!_scrollController.hasClients) {
        return;
      }
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) {
        if (_scrollController.offset > 0) {
          _scrollController.jumpTo(0);
        }
        return;
      }
      await Future.delayed(widget.startPause);
      if (!mounted || token != _loopToken || !_scrollController.hasClients) {
        return;
      }
      final forwardMs = ((maxExtent / widget.speedPixelsPerSecond) * 1000)
          .round()
          .clamp(900, 22000);
      await _scrollController.animateTo(
        maxExtent,
        duration: Duration(milliseconds: forwardMs),
        curve: Curves.linear,
      );
      if (!mounted || token != _loopToken || !_scrollController.hasClients) {
        return;
      }
      await Future.delayed(widget.endPause);
      if (!mounted || token != _loopToken || !_scrollController.hasClients) {
        return;
      }
      await _scrollController.animateTo(
        0,
        duration: widget.returnDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = DefaultTextStyle.of(context).style.merge(widget.style);
    return LayoutBuilder(
      builder: (context, constraints) {
        _queueCheck();
        if (constraints.maxWidth.isInfinite) {
          return Text(
            widget.text,
            style: textStyle,
            textAlign: widget.textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
        return ClipRect(
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Align(
                alignment: widget.alignment,
                child: Text(
                  widget.text,
                  style: textStyle,
                  textAlign: widget.textAlign,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
