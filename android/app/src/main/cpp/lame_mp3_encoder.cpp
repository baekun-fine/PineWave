#include <jni.h>

#include <algorithm>
#include <cstdint>
#include <memory>
#include <vector>

#include "lame.h"

namespace {

class LameMp3Encoder {
 public:
  LameMp3Encoder(int sample_rate, int channels, int bitrate_kbps)
      : channels_(channels) {
    lame_ = lame_init();
    if (lame_ == nullptr) {
      throw "Unable to initialize LAME.";
    }

    lame_set_in_samplerate(lame_, sample_rate);
    lame_set_num_channels(lame_, channels_);
    lame_set_brate(lame_, bitrate_kbps);
    lame_set_quality(lame_, 2);
    if (channels_ == 2) {
      lame_set_mode(lame_, JOINT_STEREO);
    }

    if (lame_init_params(lame_) < 0) {
      lame_close(lame_);
      lame_ = nullptr;
      throw "Unable to configure LAME.";
    }
  }

  ~LameMp3Encoder() {
    if (lame_ != nullptr) {
      lame_close(lame_);
      lame_ = nullptr;
    }
  }

  std::vector<unsigned char> encode(const short* interleaved_pcm, int frames) {
    if (lame_ == nullptr || interleaved_pcm == nullptr || frames <= 0) {
      return {};
    }

    std::vector<unsigned char> output(bufferSizeFor(frames));
    int encoded = 0;
    if (channels_ == 2) {
      encoded = lame_encode_buffer_interleaved(
          lame_,
          const_cast<short*>(interleaved_pcm),
          frames,
          output.data(),
          static_cast<int>(output.size()));
    } else {
      encoded = lame_encode_buffer(
          lame_,
          const_cast<short*>(interleaved_pcm),
          const_cast<short*>(interleaved_pcm),
          frames,
          output.data(),
          static_cast<int>(output.size()));
    }
    if (encoded < 0) {
      return {};
    }
    output.resize(static_cast<size_t>(encoded));
    return output;
  }

  std::vector<unsigned char> flush() {
    if (lame_ == nullptr) {
      return {};
    }

    std::vector<unsigned char> output(7200);
    const int encoded = lame_encode_flush(
        lame_,
        output.data(),
        static_cast<int>(output.size()));
    if (encoded < 0) {
      return {};
    }
    output.resize(static_cast<size_t>(encoded));
    return output;
  }

 private:
  static size_t bufferSizeFor(int frames) {
    return static_cast<size_t>((frames * 5 / 4) + 7200);
  }

  lame_t lame_ = nullptr;
  int channels_ = 2;
};

LameMp3Encoder* fromHandle(jlong handle) {
  return reinterpret_cast<LameMp3Encoder*>(static_cast<intptr_t>(handle));
}

jbyteArray toByteArray(JNIEnv* env, const std::vector<unsigned char>& bytes) {
  jbyteArray result = env->NewByteArray(static_cast<jsize>(bytes.size()));
  if (!bytes.empty()) {
    env->SetByteArrayRegion(
        result,
        0,
        static_cast<jsize>(bytes.size()),
        reinterpret_cast<const jbyte*>(bytes.data()));
  }
  return result;
}

void throwIllegalState(JNIEnv* env, const char* message) {
  jclass exception_class = env->FindClass("java/lang/IllegalStateException");
  if (exception_class != nullptr) {
    env->ThrowNew(exception_class, message);
  }
}

}  // namespace

extern "C" JNIEXPORT jlong JNICALL
Java_com_example_music_1daw_1player_LameMp3Native_create(
    JNIEnv* env,
    jobject,
    jint sample_rate,
    jint channels,
    jint bitrate_kbps) {
  try {
    auto encoder = std::make_unique<LameMp3Encoder>(
        sample_rate,
        std::max(1, std::min(2, static_cast<int>(channels))),
        std::max(32, static_cast<int>(bitrate_kbps)));
    return static_cast<jlong>(reinterpret_cast<intptr_t>(encoder.release()));
  } catch (const char* message) {
    throwIllegalState(env, message);
    return 0;
  }
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_music_1daw_1player_LameMp3Native_encode(
    JNIEnv* env,
    jobject,
    jlong handle,
    jshortArray pcm,
    jint frames) {
  auto* encoder = fromHandle(handle);
  if (encoder == nullptr || pcm == nullptr || frames <= 0) {
    return env->NewByteArray(0);
  }

  jshort* pcm_data = env->GetShortArrayElements(pcm, nullptr);
  if (pcm_data == nullptr) {
    return env->NewByteArray(0);
  }

  const auto encoded = encoder->encode(
      reinterpret_cast<const short*>(pcm_data),
      static_cast<int>(frames));
  env->ReleaseShortArrayElements(pcm, pcm_data, JNI_ABORT);
  return toByteArray(env, encoded);
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_music_1daw_1player_LameMp3Native_flush(
    JNIEnv* env,
    jobject,
    jlong handle) {
  auto* encoder = fromHandle(handle);
  if (encoder == nullptr) {
    return env->NewByteArray(0);
  }
  return toByteArray(env, encoder->flush());
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_music_1daw_1player_LameMp3Native_release(
    JNIEnv*,
    jobject,
    jlong handle) {
  delete fromHandle(handle);
}
