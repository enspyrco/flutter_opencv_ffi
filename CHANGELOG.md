# Changelog

## 0.1.0

- Initial release with core image processing operations.
- **`CvImage`** class with `NativeFinalizer` for automatic memory management.
- **I/O**: `imread`, `imwrite`, `imdecode`, `imencode`.
- **Processing**: `cvtColor`, `gaussianBlur`, `canny`, `resize`.
- **Platform support**: macOS (Homebrew), iOS and Android (auto-downloaded SDKs).
- Build hook using `native_toolchain_c` for automatic C++ compilation and linking.
- `ffigen`-generated `@Native` bindings.
