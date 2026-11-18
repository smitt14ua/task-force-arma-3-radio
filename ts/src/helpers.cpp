#include "helpers.hpp"

#ifndef _USE_MATH_DEFINES
#define _USE_MATH_DEFINES
#endif
#include <cmath>
#include <algorithm>
#include "task_force_radio.hpp"
#include <bitset>

//static_assert(static_cast<AngleRadians>(190.0_deg) > 3.f, "");
void helpers::applyILD(SampleBuffer& samples, Direction3D direction, AngleRadians viewAngle) {
    auto sampleCount = samples.getSampleCount();
    auto channels = samples.getChannels();
    if (samples.getChannels() == 2) {
        AngleRadians dir = direction.toPolarAngle() + viewAngle;
        float gainFrontLeft = AngleDegrees(-21.5f).toRadians() * dir.cosine() + 0.625f;
        float gainFrontRight = AngleDegrees(21.5f).toRadians() * dir.cosine() + 0.625f;
        //Use https://msdn.microsoft.com/en-us/library/windows/desktop/ee415798(v=vs.85).aspx for more than 2 channels

        samples.applyStereoGain(gainFrontLeft, gainFrontRight);
    }
}
#define _SPEAKER_POSITIONS_
#include <X3daudio.h>
#pragma comment(lib, "x3daudio.lib")
X3DAUDIO_HANDLE x3d_handle;
bool x3d_initialized = false;

void helpers::applyILD(SampleBuffer& samples, Position3D myPosition, Direction3D myViewDirection, Position3D emitterPosition, Direction3D emitterViewDirection, bool shouldPlayerHear, int emitterVoiceVolume) {
    ProfileFunction;
    if (!x3d_initialized) {
        X3DAudioInitialize(
            SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT,
            X3DAUDIO_SPEED_OF_SOUND,
            x3d_handle
        );
        x3d_initialized = true;
    }
    auto channels = samples.getChannels();


    //#X3DAudio cache if position didn't change.
    //#X3DAudio make player local effect so X3DAudio objects are local to every player.
    //#X3DAudio fix up vector problem
    X3DAUDIO_LISTENER listener{};


   
    std::tie(listener.OrientFront.x, listener.OrientFront.y, listener.OrientFront.z) = myViewDirection.get();
    //listener.OrientFront.z = std::clamp(listener.OrientFront.z, -0.65f, 1.f);
    //listener.OrientFront.x = listener.OrientFront.x;//East and West are mixed up
    //listener.OrientFront.y = listener.OrientFront.y;//North and South are mixed up   
    //listener.OrientFront.z = 0;


    /*
onEachFrame {

drawLine3D [ASLToAGL eyePos player2, ASLToAGL (eyePos player2) vectorAdd ((getCameraViewDirection player2) vectorMultiply 20), [1,0,1,1]];

rightVec = (getCameraViewDirection player2) vectorCrossProduct [0,0,1];
drawLine3D [ASLToAGL eyePos player2, ASLToAGL (eyePos player2) vectorAdd (rightVec vectorMultiply 20), [1,0,1,1]];

upVec = rightVec vectorCrossProduct (getCameraViewDirection player2);
drawLine3D [ASLToAGL eyePos player2, ASLToAGL (eyePos player2) vectorAdd (upVec vectorMultiply 20), [1,0,1,1]];
}
     */

    auto myRightVector = myViewDirection.crossProduct({ 0,0,1 });
    auto myUpVector = myRightVector.crossProduct(myViewDirection);
    //Looking straight up/down the view is parallel to z and the up vector degenerates to 0 (X3DAudio then yields NaN).
    //Any horizontal vector is orthogonal to a vertical view, so use north. Normal views are unchanged.
    constexpr float degenerateLengthSqr = 1e-8f;
    if (!(myUpVector.lengthSqr() > degenerateLengthSqr))
        myUpVector = Vector3D(0.f, 1.f, 0.f);

    //listener.OrientFront = { 0,-1,0 };



    std::tie(listener.OrientTop.x, listener.OrientTop.y, listener.OrientTop.z) = myUpVector.get();// Direction3D(0/*-std::get<0>(myViewDirection.get())*/, -std::get<2>(myViewDirection.get()), std::get<1>(myViewDirection.get())).get();
    
    //std::tie(listener.OrientTop.x, listener.OrientTop.y, listener.OrientTop.z) = Direction3D(-std::get<0>(myViewDirection.get()), -std::get<1>(myViewDirection.get()), 1.f).get();

    
    
    //listener.OrientTop = { 0,0,1 };
    std::tie(listener.Position.x, listener.Position.y, listener.Position.z) = emitterPosition.get();
    listener.pCone = nullptr;

    X3DAUDIO_EMITTER emitter{};
    X3DAUDIO_CONE emitterCone{};

    emitterCone.InnerAngle = DegToRad(90);
    emitterCone.OuterAngle = DegToRad(135); //https://www.researchgate.net/figure/Directivity-diagrams-Top-row-Azimuth-directivity-diagrams-for-EE-mouth-clicks-at-40cm_fig3_319413904
    emitterCone.InnerVolume = 1.8f;
    emitterCone.OuterVolume = 1.f;

    if (TFAR::config.get<bool>(Setting::voiceCone))
        emitter.pCone = &emitterCone;


    std::tie(emitter.Position.x, emitter.Position.y, emitter.Position.z) = myPosition.get();
    std::tie(emitter.OrientFront.x, emitter.OrientFront.y, emitter.OrientFront.z) = emitterViewDirection.normalized().get();
    emitter.OrientFront.y *= -1.f;
    emitter.OrientFront.x *= -1.f;

    auto emitterRightVector = emitterViewDirection.normalized().crossProduct({ 0,0,1 });
    auto emitterUpVector = emitterRightVector.crossProduct(emitterViewDirection.normalized());
    if (!(emitterUpVector.lengthSqr() > degenerateLengthSqr)) //see listener
        emitterUpVector = Vector3D(0.f, 1.f, 0.f);
    //emitter.OrientFront = { 0,1,0 };
    std::tie(emitter.OrientTop.x, emitter.OrientTop.y, emitter.OrientTop.z) = emitterUpVector.get();
    emitter.ChannelCount = 1;
    //The curve distances are relative to this: 0 (voice volume 0) divides by zero
    emitter.CurveDistanceScaler = static_cast<float>(std::max(emitterVoiceVolume, 1));
    emitter.ChannelRadius = 1.f;

    //The curve only depends on these two, cache it instead of 23 powf per call (per audio thread, few distinct volumes)
    using DistanceCurve = std::array<X3DAUDIO_DISTANCE_CURVE_POINT, 25>;
    static thread_local std::map<std::pair<bool, int>, DistanceCurve> curveCache;
    auto cachedCurve = curveCache.find({ shouldPlayerHear, emitterVoiceVolume });
    if (cachedCurve == curveCache.end()) {
        if (curveCache.size() > 64) curveCache.clear(); //bound it, the voice volume comes from other clients
        const float volumePerMeter = emitterVoiceVolume / 20.f;
        const DistanceCurve distanceCurves{
            X3DAUDIO_DISTANCE_CURVE_POINT{0.f, 1.f},
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.05, volumeAttenuation(volumePerMeter, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.10, volumeAttenuation(volumePerMeter*2, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.15, volumeAttenuation(volumePerMeter*3, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.20, volumeAttenuation(volumePerMeter*4, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.25, volumeAttenuation(volumePerMeter*5, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.30, volumeAttenuation(volumePerMeter*6, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.35, volumeAttenuation(volumePerMeter*7, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.40, volumeAttenuation(volumePerMeter*8, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.45, volumeAttenuation(volumePerMeter*9, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.50, volumeAttenuation(volumePerMeter*10, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.55, volumeAttenuation(volumePerMeter*11, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.60, volumeAttenuation(volumePerMeter*12, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.65, volumeAttenuation(volumePerMeter*13, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.70, volumeAttenuation(volumePerMeter*14, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.75, volumeAttenuation(volumePerMeter*15, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.80, volumeAttenuation(volumePerMeter*16, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.85, volumeAttenuation(volumePerMeter*17, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.90, volumeAttenuation(volumePerMeter*18, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 0.95, volumeAttenuation(volumePerMeter*19, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 1.05, volumeAttenuation(volumePerMeter*20, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 1.10, volumeAttenuation(volumePerMeter*24, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 1.15, volumeAttenuation(volumePerMeter*28, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 1.20, volumeAttenuation(volumePerMeter*32, shouldPlayerHear, emitterVoiceVolume) },
            X3DAUDIO_DISTANCE_CURVE_POINT{ 1.25, 0.0 }
        };
        cachedCurve = curveCache.emplace(std::make_pair(shouldPlayerHear, emitterVoiceVolume), distanceCurves).first;
    }
    X3DAUDIO_DISTANCE_CURVE dCurve;
    dCurve.pPoints = cachedCurve->second.data();
    dCurve.PointCount = static_cast<UINT32>(cachedCurve->second.size());
    emitter.pVolumeCurve = &dCurve;


    X3DAUDIO_DSP_SETTINGS output{ 0 };

    //The handle was initialized for front left + right
    if (channels != 2) return;
    output.SrcChannelCount = 1;
    output.DstChannelCount = channels;
    std::array<float, 2> volumeMatrix{};//#X3DAudio minimum 2 channels
    output.pMatrixCoefficients = volumeMatrix.data();

    X3DAudioCalculate(
        x3d_handle,
        &listener,
        &emitter,
        X3DAUDIO_CALCULATE_MATRIX,
        &output
    );

    float gainFrontLeft = volumeMatrix[0];
    float gainFrontRight = volumeMatrix[1];
    //Last line of defence (e.g. zero view direction): never let NaN reach the samples, fall back to plain distance attenuation
    if (!std::isfinite(gainFrontLeft) || !std::isfinite(gainFrontRight)) {
        gainFrontLeft = gainFrontRight = volumeAttenuation(myPosition.distanceTo(emitterPosition), shouldPlayerHear, emitterVoiceVolume);
    }


    samples.applyStereoGain(gainFrontLeft, gainFrontRight);
}

void helpers::shortFloatMultEx(short * data, size_t elementCount, __m128 multPack) {//#TODO use in gain and ILD for ILD multPack is {left,right,left,right}

    /*
    Thanks GCC!
    https://godbolt.org/#g:!((g:!((g:!((h:codeEditor,i:(j:1,source:'%23include+%3Calgorithm%3E%0Ashort+square(int+num)+%7B%0A++++short+samples%5B4096%5D%3B%0A%0A++++for+(size_t+i+%3D+0%3B+i+%3C+4096%3B+i%2B%2B)+samples%5Bi%5D+%3D+static_cast%3Cshort%3E(samples%5Bi%5D+*+0.999f)%3B%0A+++//std::transform(samples,+samples%2B4096,+samples,+%5B%5D(auto+samp)+%7Breturn+samp+*+0.999f%3B+%7D)%3B%0A++++return+samples%5B777%5D%3B%0A%7D'),l:'5',n:'0',o:'C%2B%2B+source+%231',t:'0')),k:50,l:'4',n:'0',o:'',s:0,t:'0'),(g:!((h:compiler,i:(compiler:g7snapshot,filters:(b:'0',commentOnly:'0',directives:'0',intel:'0'),options:'-O3',source:1),l:'5',n:'0',o:'x86-64+gcc+7+(snapshot)+(Editor+%231,+Compiler+%231)',t:'0')),k:50,l:'4',n:'0',o:'',s:0,t:'0')),l:'2',n:'0',o:'',t:'0')),version:4
    */

#ifdef _DEBUG
    if (!(CAN_USE_SSE_ON(data)) || elementCount % 8) __debugbreak();
#endif

    //Clamp in float before the conversion: cvttps returns INT_MIN for values beyond int32 (and NaN),
    //which would saturate to the wrong sign. In-range values are truncated exactly as before.
    const __m128 maxShort = _mm_set1_ps(32767.f);
    const __m128 minShort = _mm_set1_ps(-32768.f);
    const auto clampToShort = [&](__m128 v) {
        v = _mm_and_ps(v, _mm_cmpord_ps(v, v)); //NaN -> 0
        return _mm_max_ps(_mm_min_ps(v, maxShort), minShort);
    };
    for (size_t i = 0; i < elementCount; i += 8) {
        const __m128i zero = _mm_setzero_si128();
        const __m128i in = _mm_load_si128(reinterpret_cast<__m128i*>(data + i));
        const __m128i sign = _mm_cmpgt_epi16(zero, in);
        //sign extend to int32
        const __m128i lo = _mm_unpacklo_epi16(in, sign);
        const __m128i hi = _mm_unpackhi_epi16(in, sign);
        const __m128 loF = clampToShort(_mm_mul_ps(_mm_cvtepi32_ps(lo), multPack));
        const __m128 hiF = clampToShort(_mm_mul_ps(_mm_cvtepi32_ps(hi), multPack));
        //Saturating pack (the old unpack sequence truncated int32 to int16, so clipping wrapped around)
        _mm_store_si128(reinterpret_cast<__m128i*>(data + i), _mm_packs_epi32(_mm_cvttps_epi32(loF), _mm_cvttps_epi32(hiF)));
    }
}

inline float helpers::parseArmaNumber(std::string_view armaNumber) {
    //The view is not null-terminated, copy it (short numbers fit the small string buffer, no allocation)
    const std::string number(armaNumber);
    return std::strtof(number.c_str(), nullptr);
}

inline int helpers::parseArmaNumberToInt(std::string_view armaNumber) {
    return static_cast<int>(std::round(parseArmaNumber(armaNumber)));
}

bool helpers::startsWith(const std::string& shouldStartWith, const  std::string& startIn) {
    if (startIn.size() >= shouldStartWith.size()) {
        const auto res = std::mismatch(shouldStartWith.begin(), shouldStartWith.end(), startIn.begin());
        return res.first == shouldStartWith.end();
    }
    return false;
}

//http://stackoverflow.com/a/5506223
std::vector<std::string>& helpers::split(const std::string& s, char delim, std::vector<std::string>& elems) {
    std::string::size_type lastPos = 0;
    const std::string::size_type length = s.length();

    while (lastPos < length + 1) {
        std::string::size_type pos = s.find_first_of(delim, lastPos);
        if (pos == std::string::npos) {
            pos = length;
        }

        //if (pos != lastPos || !trimEmpty)
        elems.emplace_back(s.data() + lastPos, pos - lastPos);

        lastPos = pos + 1;
    }

    return elems;
}

std::vector<std::string_view>& helpers::split(std::string_view s, char delim, std::vector<std::string_view>& elems) {
    std::string::size_type lastPos = 0;
    const std::string::size_type length = s.length();

    while (lastPos < length + 1) {
        std::string::size_type pos = s.find_first_of(delim, lastPos);
        if (pos == std::string::npos) {
            pos = length;
        }

        //if (pos != lastPos || !trimEmpty)
        elems.emplace_back(s.data() + lastPos, pos - lastPos);

        lastPos = pos + 1;
    }

    return elems;
}

std::vector<std::string_view>& helpers::split(std::string_view s, char delim, std::vector<std::string_view>& elems, uint8_t maxTokens) {
    std::string::size_type lastPos = 0;
    const std::string::size_type length = s.length();

    while (lastPos < length + 1) {
        std::string::size_type pos = s.find_first_of(delim, lastPos);
        if (pos == std::string::npos) {
            pos = length;
        }

        //if (pos != lastPos || !trimEmpty)
        elems.emplace_back(s.data() + lastPos, pos - lastPos);
        if (!--maxTokens) return elems;

        lastPos = pos + 1;
    }

    return elems;
}

std::vector<std::string> helpers::split(const std::string& s, char delim) {
    std::vector<std::string> elems;
    split(s, delim, elems);
    return elems;
}

std::vector<std::string_view> helpers::split(std::string_view s, char delim) {
    std::vector<std::string_view> elems;
    split(s, delim, elems);
    return elems;
}

bool helpers::isTrue(std::string_view string) {
    if (string.length() != 4)//small speed optimization
        return string.length() == 1 && string.at(0) == '1';
    return string == "true";
}

float helpers::volumeMultiplifier(const float volumeValue) {
    const auto normalized = (volumeValue + 1) / 10.0f;
    return pow(normalized, 4);
}

std::map<std::string, FREQ_SETTINGS, std::less<>> helpers::parseFrequencies(std::string_view string) {
    std::map<std::string, FREQ_SETTINGS, std::less<>> result;
    if (string.length() < 2) return result; //substr(1) throws on an empty string
    auto sub = string.substr(1, string.length() - 2);
    if (sub.empty()) return result;
    std::vector<std::string_view> v;
    v.reserve(4);
    split(sub, ',', v);
    for (std::string_view xs : v) {
        if (xs.length() < 2) continue;
        auto parts = split(xs.substr(1, xs.length() - 2), '|');
        if (parts.size() == 3 || parts.size() == 4) {
            FREQ_SETTINGS settings;
            settings.volume = parseArmaNumberToInt(parts[1]);
            settings.stereoMode = static_cast<stereoMode>(parseArmaNumberToInt(parts[2]));
            if (parts.size() == 4)
                settings.radioClassname = parts[3];
            result.insert_or_assign(std::string(parts[0]),settings);
        }
    }
    return result;
}

#include <utility>

vehicleDescriptor helpers::getVehicleDescriptor(std::string_view vehicleID) {
    vehicleDescriptor result;
    //"2:390\x100.6\x10gunner"
    if (vehicleID == "no") {
        result.vehicleName = "no";
        result.vehicleIsolation = 0.f;
        result.intercomSlot = -1;
        return result;
    }
    auto split = helpers::split(vehicleID, '\x10');
    if (split.size() < 3) return result; //I don't listen to morons!!
    result.vehicleName = split[0]; // hear vehicle
    auto& isolation = split[1];
    if (isolation == "turnout")
        result.vehicleIsolation = 0.f;
    else
        result.vehicleIsolation = parseArmaNumber(split[1]); // hear
    result.intercomSlot = parseArmaNumberToInt(split[2]);//vehicleDescriptor::stringToVehiclePosition(split[2]);

    return result;
}

float helpers::distanceForDiverRadio() {
    return DD_MIN_DISTANCE + (DD_MAX_DISTANCE - DD_MIN_DISTANCE) * (1.0f - TFAR::getInstance().m_gameData.wavesLevel); //#TODO WTF?! underwater range is influenced by wave intensity?
}

namespace {
    struct DetachedTask {
        std::function<void()> function;
        HMODULE module;
    };

    DWORD WINAPI detachedThreadProc(LPVOID parameter) {
        HMODULE module;
        {
            const std::unique_ptr<DetachedTask> task(static_cast<DetachedTask*>(parameter));
            module = task->module;
            try {
                task->function();
            } catch (...) {}
        } //Everything of ours is destroyed before the module reference is dropped
        //Doesn't return into the (possibly unloaded) module
        FreeLibraryAndExitThread(module, 0);
    }
}

void helpers::runDetached(std::function<void()> function) {
    HMODULE module = nullptr;
    //Takes a reference on our own DLL, so it stays loaded while the thread runs
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS, reinterpret_cast<LPCWSTR>(&detachedThreadProc), &module))
        return;
    auto task = std::make_unique<DetachedTask>(DetachedTask{ std::move(function), module });
    const HANDLE thread = CreateThread(nullptr, 0, &detachedThreadProc, task.get(), 0, nullptr);
    if (!thread) {
        FreeLibrary(module);
        return;
    }
    task.release(); //Owned by the thread now
    CloseHandle(thread);
}
