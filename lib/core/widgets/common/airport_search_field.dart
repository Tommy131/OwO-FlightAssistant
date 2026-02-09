import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../apps/data/airports_database.dart';

/// 机场搜索输入框组件
/// 支持ICAO代码输入和智能搜索建议
class AirportSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color? iconColor;
  final String? Function(String?)? validator;
  final void Function(AirportInfo?)? onAirportSelected;
  final bool required;

  const AirportSearchField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.iconColor,
    this.validator,
    this.onAirportSelected,
    this.required = false,
  });

  @override
  State<AirportSearchField> createState() => _AirportSearchFieldState();
}

class _AirportSearchFieldState extends State<AirportSearchField> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<AirportInfo> _suggestions = [];
  bool _isSearching = false;
  bool _isSelectingFromList = false; // 标记是否正在从列表选择
  String? _validationError; // 自定义验证错误信息

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text.trim().toUpperCase();

    // 清除之前的验证错误
    if (_validationError != null) {
      setState(() => _validationError = null);
    }

    if (text.isEmpty) {
      _removeOverlay();
      if (widget.onAirportSelected != null) {
        widget.onAirportSelected!(null);
      }
      return;
    }

    // 如果是完整的4位ICAO代码，自动校验
    if (text.length == 4 && RegExp(r'^[A-Z0-9]{4}$').hasMatch(text)) {
      _validateAndNotify(text);
      _removeOverlay();
      return;
    }

    // 搜索建议
    if (text.length >= 2) {
      _searchSuggestions(text);
    } else {
      _removeOverlay();
    }
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && !_isSelectingFromList) {
      // 失焦时执行校验
      final text = widget.controller.text.trim().toUpperCase();
      if (text.isNotEmpty) {
        if (text.length == 4 && RegExp(r'^[A-Z0-9]{4}$').hasMatch(text)) {
          _validateAndNotify(text);
        } else if (text.length > 0) {
          // 输入了内容但不是有效的ICAO格式
          if (mounted) {
            setState(() => _validationError = '请输入4位有效的ICAO代码');
          }
          if (widget.onAirportSelected != null) {
            widget.onAirportSelected!(null);
          }
        }
      }

      // 延迟移除overlay，给点击事件足够的时间处理
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_isSelectingFromList) {
          _removeOverlay();
        }
      });
    }
  }

  /// 验证ICAO代码并通知
  Future<void> _validateAndNotify(String icao) async {
    try {
      final airport = AirportsDatabase.findByIcao(icao);

      if (airport != null) {
        // 找到机场，清除错误
        if (mounted) {
          setState(() => _validationError = null);
        }
        if (widget.onAirportSelected != null) {
          widget.onAirportSelected!(airport);
        }
      } else {
        // 未找到机场
        if (mounted) {
          setState(() => _validationError = '未找到机场: $icao');
        }
        if (widget.onAirportSelected != null) {
          widget.onAirportSelected!(null);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _validationError = '查询失败');
      }
      if (widget.onAirportSelected != null) {
        widget.onAirportSelected!(null);
      }
    }
  }

  Future<void> _searchSuggestions(String query) async {
    setState(() => _isSearching = true);

    try {
      // 使用AirportsDatabase的search方法
      final results = AirportsDatabase.search(query);

      // 限制结果数量
      final limitedResults = results.take(5).toList();

      if (mounted && _focusNode.hasFocus) {
        setState(() {
          _suggestions = limitedResults;
          _isSearching = false;
        });

        if (limitedResults.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: _getFieldWidth(),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, _getFieldHeight() + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: _buildSuggestionsList(),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  double _getFieldWidth() {
    final renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.width ?? 300;
  }

  double _getFieldHeight() {
    final renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.height ?? 56;
  }

  Widget _buildSuggestionsList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final airport = _suggestions[index];
          return InkWell(
            onTap: () {
              // 标记正在选择
              _isSelectingFromList = true;

              // 更新文本框
              widget.controller.text = airport.icaoCode;

              // 清除验证错误
              setState(() => _validationError = null);

              // 通知选择
              if (widget.onAirportSelected != null) {
                widget.onAirportSelected!(airport);
              }

              // 关闭建议列表
              _removeOverlay();

              // 取消焦点
              _focusNode.unfocus();

              // 重置选择标记
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  _isSelectingFromList = false;
                }
              });
            },
            child: ListTile(
              dense: true,
              leading: Icon(
                Icons.flight,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                airport.icaoCode,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                airport.nameChinese,
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: widget.required ? '${widget.label} *' : widget.label,
          hintText: widget.hint,
          prefixIcon: Icon(widget.icon, color: widget.iconColor),
          suffixIcon: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
          border: const OutlineInputBorder(),
          errorText: _validationError,
          errorMaxLines: 2,
        ),
        // 只允许输入英文字母和数字
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          LengthLimitingTextInputFormatter(4), // 限制最多4个字符
        ],
        validator: widget.validator,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.next, // 设置键盘动作为"下一个"
        onFieldSubmitted: (value) {
          // 回车时执行校验
          final text = value.trim().toUpperCase();
          if (text.isNotEmpty) {
            if (text.length == 4 && RegExp(r'^[A-Z0-9]{4}$').hasMatch(text)) {
              _validateAndNotify(text);
            } else {
              // 输入了内容但不是有效的ICAO格式
              if (mounted) {
                setState(() => _validationError = '请输入4位有效的ICAO代码');
              }
              if (widget.onAirportSelected != null) {
                widget.onAirportSelected!(null);
              }
            }
          }
        },
        onChanged: (value) {
          // 自动转换为大写
          final upperValue = value.toUpperCase();
          if (value != upperValue) {
            widget.controller.value = widget.controller.value.copyWith(
              text: upperValue,
              selection: TextSelection.collapsed(offset: upperValue.length),
            );
          }
        },
      ),
    );
  }
}
