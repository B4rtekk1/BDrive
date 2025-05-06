import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Filesicons {
  static const Map<String, String> exToIcon = {
    "pdf": "assets/icons/pdf.svg",
    //"doc": "assets/icons/doc.svg",
    "docx": "assets/icons/doc.svg",
    "odt": "assets/icons/odt.svg",
    "ai": "assets/icons/ai.svg",
    "psd": "assets/icons/psd.svg",
    "bmp": "assets/icons/bmp.svg",
    "md": "assets/icons/md.svg",
    "tex": "assets/icons/tex.svg",
    "tif": "assets/icons/tif.svg",
    "folder": "assets/icons/folder.svg",
    //"xls": "assets/icons/xls.svg",
    //"xlsx": "assets/icons/xls.svg",
    //"ppt": "assets/icons/ppt.svg",
    //"pptx": "assets/icons/ppt.svg",
    "txt": "assets/icons/txt.svg",
    "jpg": "assets/icons/jpg.svg",
    "jpeg": "assets/icons/jpg.svg",
    "png": "assets/icons/png.svg",
    "gif": "assets/icons/gif.svg",
    //"zip": "assets/icons/zip.svg",
    //"rar": "assets/icons/zip.svg",
    "svg": "assets/icons/svg.svg",
    //"html": "assets/icons/html.svg",
    //"css": "assets/icons/css.svg",
    //"js": "assets/icons/js.svg",
    //"json": "assets/icons/json.svg",
    //"xml": "assets/icons/xml.svg",
    "default": "assets/icons/file.svg",
  };

  static Widget getIconForExtension(String extension, double size) {
    final iconPath = exToIcon[extension.toLowerCase()] ?? 'assets/icons/file.svg';
    return SvgPicture.asset(
      iconPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
