#ifndef OPENCV_WRAPPER_H
#define OPENCV_WRAPPER_H

#include <stdint.h>

// Platform-specific export macro.
#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// ---------------------------------------------------------------------------
// Opaque handle to a cv::Mat
// ---------------------------------------------------------------------------
typedef struct CvMat CvMat;

// ---------------------------------------------------------------------------
// Version
// ---------------------------------------------------------------------------

/// Returns the OpenCV version string (e.g. "4.13.0").
FFI_PLUGIN_EXPORT const char* opencv_version(void);

// ---------------------------------------------------------------------------
// Mat lifecycle
// ---------------------------------------------------------------------------

/// Creates an empty Mat.
FFI_PLUGIN_EXPORT CvMat* opencv_mat_create(void);

/// Destroys a Mat and frees its memory.
FFI_PLUGIN_EXPORT void opencv_mat_destroy(CvMat* mat);

/// Creates a deep copy of a Mat.
FFI_PLUGIN_EXPORT CvMat* opencv_mat_clone(const CvMat* mat);

// ---------------------------------------------------------------------------
// Mat properties
// ---------------------------------------------------------------------------

FFI_PLUGIN_EXPORT int opencv_mat_rows(const CvMat* mat);
FFI_PLUGIN_EXPORT int opencv_mat_cols(const CvMat* mat);
FFI_PLUGIN_EXPORT int opencv_mat_type(const CvMat* mat);
FFI_PLUGIN_EXPORT int opencv_mat_channels(const CvMat* mat);
FFI_PLUGIN_EXPORT int opencv_mat_empty(const CvMat* mat);
FFI_PLUGIN_EXPORT uint8_t* opencv_mat_data(const CvMat* mat);

// ---------------------------------------------------------------------------
// Image I/O
// ---------------------------------------------------------------------------

/// Reads an image from a file. Returns NULL on failure (check opencv_get_last_error).
FFI_PLUGIN_EXPORT CvMat* opencv_imread(const char* filename, int flags);

/// Writes an image to a file. Returns 1 on success, 0 on failure.
FFI_PLUGIN_EXPORT int opencv_imwrite(const char* filename, const CvMat* mat);

/// Decodes an image from a memory buffer.
FFI_PLUGIN_EXPORT CvMat* opencv_imdecode(const uint8_t* buf, int buf_len, int flags);

/// Encodes an image to a memory buffer. The caller must free the buffer
/// with opencv_free_buffer. Sets *out_len to the buffer length.
FFI_PLUGIN_EXPORT uint8_t* opencv_imencode(const char* ext, const CvMat* mat, int* out_len);

/// Frees a buffer allocated by opencv_imencode.
FFI_PLUGIN_EXPORT void opencv_free_buffer(uint8_t* buf);

// ---------------------------------------------------------------------------
// Image processing
// ---------------------------------------------------------------------------

/// Converts color space. See cv::ColorConversionCodes.
FFI_PLUGIN_EXPORT CvMat* opencv_cvt_color(const CvMat* src, int code);

/// Applies Gaussian blur. ksize must be odd and positive.
FFI_PLUGIN_EXPORT CvMat* opencv_gaussian_blur(
    const CvMat* src, int ksize, double sigma_x, double sigma_y);

/// Applies Canny edge detection.
FFI_PLUGIN_EXPORT CvMat* opencv_canny(
    const CvMat* src, double threshold1, double threshold2);

/// Resizes an image. See cv::InterpolationFlags.
FFI_PLUGIN_EXPORT CvMat* opencv_resize(
    const CvMat* src, int width, int height, int interpolation);

// ---------------------------------------------------------------------------
// Error handling (thread-local)
// ---------------------------------------------------------------------------

/// Returns the last error message, or NULL if no error.
FFI_PLUGIN_EXPORT const char* opencv_get_last_error(void);

/// Clears the last error.
FFI_PLUGIN_EXPORT void opencv_clear_error(void);

#ifdef __cplusplus
}
#endif

#endif // OPENCV_WRAPPER_H
