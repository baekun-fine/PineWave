cmake_minimum_required(VERSION 3.22.1)

project(music_daw_audio LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(FREEVERB3_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../../third_party/freeverb3")
set(LAME_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../../third_party/lame")

add_library(
    music_daw_audio
    SHARED
    freeverb3_bridge.cpp
    lame_mp3_encoder.cpp
    "${LAME_ROOT}/libmp3lame/VbrTag.c"
    "${LAME_ROOT}/libmp3lame/bitstream.c"
    "${LAME_ROOT}/libmp3lame/encoder.c"
    "${LAME_ROOT}/libmp3lame/fft.c"
    "${LAME_ROOT}/libmp3lame/gain_analysis.c"
    "${LAME_ROOT}/libmp3lame/id3tag.c"
    "${LAME_ROOT}/libmp3lame/lame.c"
    "${LAME_ROOT}/libmp3lame/mpglib_interface.c"
    "${LAME_ROOT}/libmp3lame/newmdct.c"
    "${LAME_ROOT}/libmp3lame/presets.c"
    "${LAME_ROOT}/libmp3lame/psymodel.c"
    "${LAME_ROOT}/libmp3lame/quantize.c"
    "${LAME_ROOT}/libmp3lame/quantize_pvt.c"
    "${LAME_ROOT}/libmp3lame/reservoir.c"
    "${LAME_ROOT}/libmp3lame/set_get.c"
    "${LAME_ROOT}/libmp3lame/tables.c"
    "${LAME_ROOT}/libmp3lame/takehiro.c"
    "${LAME_ROOT}/libmp3lame/util.c"
    "${LAME_ROOT}/libmp3lame/vbrquantize.c"
    "${LAME_ROOT}/libmp3lame/version.c"
    "${FREEVERB3_ROOT}/freeverb/allpass.cpp"
    "${FREEVERB3_ROOT}/freeverb/biquad.cpp"
    "${FREEVERB3_ROOT}/freeverb/comb.cpp"
    "${FREEVERB3_ROOT}/freeverb/delay.cpp"
    "${FREEVERB3_ROOT}/freeverb/efilter.cpp"
    "${FREEVERB3_ROOT}/freeverb/revbase.cpp"
    "${FREEVERB3_ROOT}/freeverb/revmodel.cpp"
    "${FREEVERB3_ROOT}/freeverb/slot.cpp"
    "${FREEVERB3_ROOT}/freeverb/src.cpp"
    "${FREEVERB3_ROOT}/freeverb/utils.cpp"
    "${FREEVERB3_ROOT}/libsamplerate2/samplerate.c"
    "${FREEVERB3_ROOT}/libsamplerate2/samplerate_common.c"
    "${FREEVERB3_ROOT}/libsamplerate2/src_common.c"
    "${FREEVERB3_ROOT}/libsamplerate2/src_linear.c"
    "${FREEVERB3_ROOT}/libsamplerate2/src_sinc.c"
    "${FREEVERB3_ROOT}/libsamplerate2/src_zoh.c"
)

target_include_directories(
    music_daw_audio
    PRIVATE
    "${FREEVERB3_ROOT}"
    "${FREEVERB3_ROOT}/freeverb"
    "${FREEVERB3_ROOT}/libsamplerate2"
    "${LAME_ROOT}"
    "${LAME_ROOT}/include"
    "${LAME_ROOT}/libmp3lame"
)

target_compile_definitions(
    music_daw_audio
    PRIVATE
    LIBFV3_FLOAT
    LIBSRATE2_FLOAT
    HAVE_CONFIG_H
)

target_compile_options(
    music_daw_audio
    PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:-Wno-deprecated>
    $<$<COMPILE_LANGUAGE:CXX>:-Wno-register>
)

find_library(log-lib log)
target_link_libraries(music_daw_audio PRIVATE ${log-lib})
