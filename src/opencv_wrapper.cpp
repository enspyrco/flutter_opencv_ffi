#include "opencv_wrapper.h"

#include <cstring>
#include <string>
#include <vector>

#include <opencv2/core.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

// ---------------------------------------------------------------------------
// Opaque handle — wraps a cv::Mat inside a plain C struct.
// ---------------------------------------------------------------------------
struct CvMat {
  cv::Mat mat;
};

// ---------------------------------------------------------------------------
// Thread-local error storage
// ---------------------------------------------------------------------------
static thread_local std::string g_last_error;

static void set_error(const std::string& msg) { g_last_error = msg; }
static void clear_error_internal() { g_last_error.clear(); }

// Macro to wrap every public function body in a try/catch.
#define OPENCV_TRY try { clear_error_internal();
#define OPENCV_CATCH_RETURN(ret) \
  } catch (const cv::Exception& e) { \
    set_error(e.what()); \
    return ret; \
  } catch (const std::exception& e) { \
    set_error(e.what()); \
    return ret; \
  }

// ---------------------------------------------------------------------------
// Version
// ---------------------------------------------------------------------------
const char* opencv_version(void) { return CV_VERSION; }

// ---------------------------------------------------------------------------
// Mat lifecycle
// ---------------------------------------------------------------------------
CvMat* opencv_mat_create(void) {
  OPENCV_TRY
  return new CvMat();
  OPENCV_CATCH_RETURN(nullptr)
}

void opencv_mat_destroy(CvMat* mat) {
  delete mat;
}

CvMat* opencv_mat_clone(const CvMat* mat) {
  OPENCV_TRY
  if (!mat) {
    set_error("null mat pointer");
    return nullptr;
  }
  auto* result = new CvMat();
  result->mat = mat->mat.clone();
  return result;
  OPENCV_CATCH_RETURN(nullptr)
}

// ---------------------------------------------------------------------------
// Mat properties
// ---------------------------------------------------------------------------
int opencv_mat_rows(const CvMat* mat) { return mat ? mat->mat.rows : 0; }
int opencv_mat_cols(const CvMat* mat) { return mat ? mat->mat.cols : 0; }
int opencv_mat_type(const CvMat* mat) { return mat ? mat->mat.type() : 0; }
int opencv_mat_channels(const CvMat* mat) { return mat ? mat->mat.channels() : 0; }
int opencv_mat_empty(const CvMat* mat) { return mat ? (mat->mat.empty() ? 1 : 0) : 1; }
uint8_t* opencv_mat_data(const CvMat* mat) { return mat ? mat->mat.data : nullptr; }

// ---------------------------------------------------------------------------
// Image I/O
// ---------------------------------------------------------------------------
CvMat* opencv_imread(const char* filename, int flags) {
  OPENCV_TRY
  cv::Mat img = cv::imread(filename, flags);
  if (img.empty()) {
    set_error(std::string("imread failed: ") + filename);
    return nullptr;
  }
  auto* result = new CvMat();
  result->mat = std::move(img);
  return result;
  OPENCV_CATCH_RETURN(nullptr)
}

int opencv_imwrite(const char* filename, const CvMat* mat) {
  OPENCV_TRY
  if (!mat) {
    set_error("null mat pointer");
    return 0;
  }
  return cv::imwrite(filename, mat->mat) ? 1 : 0;
  OPENCV_CATCH_RETURN(0)
}

CvMat* opencv_imdecode(const uint8_t* buf, int buf_len, int flags) {
  OPENCV_TRY
  cv::Mat raw(1, buf_len, CV_8UC1, const_cast<uint8_t*>(buf));
  cv::Mat img = cv::imdecode(raw, flags);
  if (img.empty()) {
    set_error("imdecode failed");
    return nullptr;
  }
  auto* result = new CvMat();
  result->mat = std::move(img);
  return result;
  OPENCV_CATCH_RETURN(nullptr)
}

uint8_t* opencv_imencode(const char* ext, const CvMat* mat, int* out_len) {
  OPENCV_TRY
  if (!mat || !out_len) {
    set_error("null pointer argument");
    return nullptr;
  }
  std::vector<uint8_t> buf;
  if (!cv::imencode(ext, mat->mat, buf)) {
    set_error(std::string("imencode failed for extension: ") + ext);
    return nullptr;
  }
  // Allocate a buffer the caller will free with opencv_free_buffer.
  auto* result = new uint8_t[buf.size()];
  std::memcpy(result, buf.data(), buf.size());
  *out_len = static_cast<int>(buf.size());
  return result;
  OPENCV_CATCH_RETURN(nullptr)
}

void opencv_free_buffer(uint8_t* buf) {
  delete[] buf;
}

// ---------------------------------------------------------------------------
// Image processing
// ---------------------------------------------------------------------------
CvMat* opencv_cvt_color(const CvMat* src, int code) {
  OPENCV_TRY
  if (!src) {
    set_error("null mat pointer");
    return nullptr;
  }
  auto* dst = new CvMat();
  cv::cvtColor(src->mat, dst->mat, code);
  return dst;
  OPENCV_CATCH_RETURN(nullptr)
}

CvMat* opencv_gaussian_blur(
    const CvMat* src, int ksize, double sigma_x, double sigma_y) {
  OPENCV_TRY
  if (!src) {
    set_error("null mat pointer");
    return nullptr;
  }
  auto* dst = new CvMat();
  cv::GaussianBlur(src->mat, dst->mat, cv::Size(ksize, ksize), sigma_x, sigma_y);
  return dst;
  OPENCV_CATCH_RETURN(nullptr)
}

CvMat* opencv_canny(const CvMat* src, double threshold1, double threshold2) {
  OPENCV_TRY
  if (!src) {
    set_error("null mat pointer");
    return nullptr;
  }
  auto* dst = new CvMat();
  cv::Canny(src->mat, dst->mat, threshold1, threshold2);
  return dst;
  OPENCV_CATCH_RETURN(nullptr)
}

CvMat* opencv_resize(
    const CvMat* src, int width, int height, int interpolation) {
  OPENCV_TRY
  if (!src) {
    set_error("null mat pointer");
    return nullptr;
  }
  auto* dst = new CvMat();
  cv::resize(src->mat, dst->mat, cv::Size(width, height), 0, 0, interpolation);
  return dst;
  OPENCV_CATCH_RETURN(nullptr)
}

// ---------------------------------------------------------------------------
// Error handling
// ---------------------------------------------------------------------------
const char* opencv_get_last_error(void) {
  return g_last_error.empty() ? nullptr : g_last_error.c_str();
}

void opencv_clear_error(void) {
  clear_error_internal();
}
