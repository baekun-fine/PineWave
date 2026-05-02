#include <jni.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <memory>
#include <vector>

#include "freeverb/revmodel.hpp"

namespace {

float clamp01(float value) {
  return std::max(0.0f, std::min(1.0f, value));
}

class Freeverb3Processor {
 public:
  explicit Freeverb3Processor(int sample_rate) : sample_rate_(sample_rate) {
    reverb_.setSampleRate(static_cast<float>(sample_rate_));
    reverb_.setwet(0.0f);
    reverb_.setdry(1.0f);
    reverb_.setroomsize(0.58f);
    reverb_.setdamp(0.42f);
    reverb_.setPreDelay(32.0f);
    reverb_.setwidth(0.78f);
    reverb_.mute();
  }

  void reset() { reverb_.mute(); }

  void setParameters(
      float amount,
      float room_size,
      float decay,
      float damp,
      float pre_delay_ms,
      float width) {
    amount_ = clamp01(amount);
    const float room = clamp01((room_size * 0.55f) + (decay * 0.45f));
    reverb_.setroomsize(room);
    reverb_.setdamp(clamp01(damp));
    reverb_.setPreDelay(std::max(0.0f, std::min(120.0f, pre_delay_ms)));
    reverb_.setwidth(clamp01(width));
    reverb_.setwet(amount_);
    reverb_.setdry(std::max(0.0f, 1.0f - (amount_ * 0.35f)));
  }

  void process(const float* input_interleaved, float* output_interleaved, int frames) {
    if (frames <= 0) {
      return;
    }

    if (amount_ <= 0.0005f) {
      std::copy(input_interleaved, input_interleaved + (frames * 2), output_interleaved);
      return;
    }

    ensureCapacity(frames);
    for (int i = 0; i < frames; ++i) {
      input_l_[i] = input_interleaved[i * 2];
      input_r_[i] = input_interleaved[(i * 2) + 1];
    }

    reverb_.processreplace(
        input_l_.data(),
        input_r_.data(),
        output_l_.data(),
        output_r_.data(),
        frames);

    for (int i = 0; i < frames; ++i) {
      output_interleaved[i * 2] = output_l_[i];
      output_interleaved[(i * 2) + 1] = output_r_[i];
    }
  }

 private:
  void ensureCapacity(int frames) {
    if (static_cast<int>(input_l_.size()) >= frames) {
      return;
    }
    input_l_.resize(frames);
    input_r_.resize(frames);
    output_l_.resize(frames);
    output_r_.resize(frames);
  }

  int sample_rate_;
  float amount_ = 0.0f;
  fv3::revmodel_f reverb_;
  std::vector<float> input_l_;
  std::vector<float> input_r_;
  std::vector<float> output_l_;
  std::vector<float> output_r_;
};

Freeverb3Processor* fromHandle(jlong handle) {
  return reinterpret_cast<Freeverb3Processor*>(static_cast<intptr_t>(handle));
}

}  // namespace

extern "C" JNIEXPORT jlong JNICALL
Java_com_example_music_1daw_1player_Freeverb3Native_create(
    JNIEnv*,
    jobject,
    jint sample_rate) {
  auto processor = std::make_unique<Freeverb3Processor>(sample_rate);
  return static_cast<jlong>(reinterpret_cast<intptr_t>(processor.release()));
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_music_1daw_1player_Freeverb3Native_release(
    JNIEnv*,
    jobject,
    jlong handle) {
  delete fromHandle(handle);
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_music_1daw_1player_Freeverb3Native_reset(
    JNIEnv*,
    jobject,
    jlong handle) {
  if (auto* processor = fromHandle(handle)) {
    processor->reset();
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_music_1daw_1player_Freeverb3Native_setParameters(
    JNIEnv*,
    jobject,
    jlong handle,
    jfloat amount,
    jfloat room_size,
    jfloat decay,
    jfloat damp,
    jfloat pre_delay_ms,
    jfloat width) {
  if (auto* processor = fromHandle(handle)) {
    processor->setParameters(amount, room_size, decay, damp, pre_delay_ms, width);
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_music_1daw_1player_Freeverb3Native_process(
    JNIEnv* env,
    jobject,
    jlong handle,
    jfloatArray input,
    jfloatArray output,
    jint frames) {
  auto* processor = fromHandle(handle);
  if (processor == nullptr || input == nullptr || output == nullptr || frames <= 0) {
    return;
  }

  jfloat* input_data = env->GetFloatArrayElements(input, nullptr);
  jfloat* output_data = env->GetFloatArrayElements(output, nullptr);
  if (input_data == nullptr || output_data == nullptr) {
    if (input_data != nullptr) {
      env->ReleaseFloatArrayElements(input, input_data, JNI_ABORT);
    }
    if (output_data != nullptr) {
      env->ReleaseFloatArrayElements(output, output_data, 0);
    }
    return;
  }

  processor->process(input_data, output_data, frames);

  env->ReleaseFloatArrayElements(input, input_data, JNI_ABORT);
  env->ReleaseFloatArrayElements(output, output_data, 0);
}
