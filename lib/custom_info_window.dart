/// A widget based custom info window for Maps_flutter package.
library custom_info_window;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Controller to add, update and control the custom info window.
class CustomInfoWindowController {
  /// Add custom [Widget] and [Marker]'s [LatLng] to [CustomInfoWindow] and make it visible.
  /// Offset to maintain space between [Marker] and [CustomInfoWindow].
  /// Height of [CustomInfoWindow].
  /// Width of [CustomInfoWindow].
  Function(Widget, LatLng, double, double, double)? addInfoWindow;

  /// Notifies [CustomInfoWindow] to redraw as per change in position.
  VoidCallback? onCameraMove;

  /// Hides [CustomInfoWindow].
  VoidCallback? hideInfoWindow;

  /// Shows [CustomInfoWindow].
  VoidCallback? showInfoWindow;

  /// Holds [GoogleMapController] for calculating [CustomInfoWindow] position.
  GoogleMapController? googleMapController;

  void dispose() {
    addInfoWindow = null;
    onCameraMove = null;
    hideInfoWindow = null;
    showInfoWindow = null;
    googleMapController = null;
  }
}

/// A stateful widget responsible to create widget based custom info window.
class CustomInfoWindow extends StatefulWidget {
  /// A [CustomInfoWindowController] to manipulate [CustomInfoWindow] state.
  final CustomInfoWindowController controller;

  /// Callback when the info window position changes.
  /// Provides top, left, width, and height of the info window.
  final Function(double top, double left, double width, double height) onChange;

  const CustomInfoWindow(
    this.onChange, {
      super.key,
      required this.controller,
    });

  @override
  _CustomInfoWindowState createState() => _CustomInfoWindowState();
}

class _CustomInfoWindowState extends State<CustomInfoWindow> {
  bool _showNow = false;
  double _leftMargin = 0;
  double _topMargin = 0;
  Widget? _child;
  LatLng? _latLng;
  double? _offset;
  double? _height;
  double? _width;

  @override
  void initState() {
    super.initState();
    widget.controller.addInfoWindow = _addInfoWindow;
    widget.controller.onCameraMove = _onCameraMove;
    widget.controller.hideInfoWindow = _hideInfoWindow;
    widget.controller.showInfoWindow = _showInfoWindow;
  }

  /// Calculate the position of [CustomInfoWindow] and redraw on screen.
  void _updateInfoWindow() async {
    if (_latLng == null ||
        _child == null ||
        _offset == null ||
        _height == null ||
        _width == null ||
        widget.controller.googleMapController == null ||
        !mounted) { // 위젯이 마운트되었는지 확인
      return;
    }

    final ScreenCoordinate screenCoordinate = await widget
        .controller.googleMapController!
        .getScreenCoordinate(_latLng!);

    double devicePixelRatio;
    if (kIsWeb) {
      // 웹에서는 getScreenCoordinate가 논리적 픽셀을 반환하므로 devicePixelRatio는 1.0
      devicePixelRatio = 1.0;
    } else {
      // 모바일 플랫폼 (Android, iOS)에서는 실제 devicePixelRatio를 사용
      // context가 유효한지 확인하기 위해 mounted를 체크
      if (mounted) {
        devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      } else {
        // context가 유효하지 않으면 기본값 또는 이전 값을 사용하거나 업데이트를 중단
        devicePixelRatio = 1.0;
        return;
      }
    }

    // x 좌표는 정보창 너비의 절반만큼 왼쪽으로 이동
    double left = (screenCoordinate.x.toDouble() / devicePixelRatio) - (_width! / 2);
    // y 좌표는 정보창 높이와 offset만큼 위로 이동
    double top = (screenCoordinate.y.toDouble() / devicePixelRatio) - (_offset! + _height!);

    if (mounted) { // setState를 호출하기 전에 mounted 상태를 확인
      setState(() {
        _showNow = true;
        _leftMargin = left;
        _topMargin = top;
      });
      widget.onChange.call(top, left, _width!, _height!);
    }
  }

  /// Assign the [Widget] and [Marker]'s [LatLng].
  /// [offsetValue] is the vertical space between the top of the marker and the bottom of the info window.
  /// [infoWindowHeight] is the height of the info window widget.
  /// [infoWindowWidth] is the width of the info window widget.
  void _addInfoWindow(Widget child, LatLng latLng, double offsetValue,
      double infoWindowHeight, double infoWindowWidth) {
    _child = child;
    _latLng = latLng;
    _offset = offsetValue; // 마커 y좌표에서 (정보창 높이 + offset) 만큼 위로 올립니다.
    _height = infoWindowHeight;
    _width = infoWindowWidth;
    if (mounted) { // initState에서 호출될 수 있으므로 mounted 체크
      _updateInfoWindow();
    } else { // 아직 마운트되지 않았다면, 마운트된 후 첫 빌드에서 처리되도록 예약 (예: addPostFrameCallback)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateInfoWindow();
      });
    }
  }

  /// Notifies camera movements on [GoogleMap].
  void _onCameraMove() {
    if (!_showNow || !mounted) return;
    _updateInfoWindow();
  }

  /// Disables [CustomInfoWindow] visibility.
  void _hideInfoWindow() {
    if (mounted) {
      setState(() {
        _showNow = false;
      });
    }
  }

  /// Enables [CustomInfoWindow] visibility.
  void _showInfoWindow() {
    // _updateInfoWindow는 위치를 다시 계산하고 _showNow를 true로 설정
    if (mounted) {
      _updateInfoWindow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _leftMargin,
      top: _topMargin,
      child: Visibility(
        visible: _showNow &&
            _child != null &&
            _latLng != null,
        child: SizedBox(
          height: _height,
          width: _width,
          child: _child,
        ),
      ),
    );
  }
}