#pragma once

#include <clunk/hrtf.h>

class Clunk
{
public:


	void process(SampleBuffer& samples, Direction3D pos, AngleRadians direction)
	{
		auto [x, y, z] = pos.get();

		//| cos θ - sin θ   0 | | x | | x cos θ - y sin θ | | x'|
		//| sin θ    cos θ   0 | | y | = | x sin θ + y cos θ | = | y'|
		//| 0       0      1 | | z | | z | | z'|


		const auto x_ = x * direction.cosine() - y * direction.sine();
		const auto y_ = x * direction.sine() + y * direction.cosine();

        auto channels = samples.getChannels();
        auto sampleCount = samples.getSampleCount();
		input_buffer.insert(input_buffer.end(), samples.begin(), samples.end());

		if (input_buffer.size() > clunk::Hrtf::WINDOW_SIZE * channels * 2u)
		{

			const auto to_process = static_cast<int>(input_buffer.size());

			//Hrtf::process only reads src: lend it input_buffer's memory instead of copying it.
			//unlink() before src is destroyed so clunk::Buffer doesn't free memory it doesn't own.
			clunk::Buffer src;
			struct UnlinkGuard {
				clunk::Buffer& buffer;
				~UnlinkGuard() { buffer.unlink(); }
			} unlinkSrc{ src };
			src.set_data(input_buffer.data(), to_process * sizeof(short), true);


			const auto output_size = to_process - clunk::Hrtf::WINDOW_SIZE * channels * 2;

			//Reused between calls. clunk::Buffer allocates with realloc and releases with ::free
			//(the old code handed it a new[] buffer: mismatched deallocation).
			dst_buffer.set_size(output_size * sizeof(short));
			dst_buffer.fill(0);

			const auto processed = hrft->process(SAMPLE_RATE, dst_buffer, channels, src, channels, clunk::v3f(x_, y_, z), 1.0f);
			input_buffer.erase(input_buffer.begin(), input_buffer.begin() + processed * channels); //Erase processed data and keep leftover

			const auto dst_s = static_cast<const short*>(dst_buffer.get_ptr());
			output_buffer.insert(output_buffer.end(), dst_s, dst_s + output_size);

		}

		if (output_buffer.size() < sampleCount * channels) {
            samples.setToNull();
		} else {
			memcpy(samples.begin(), output_buffer.data(), sampleCount * channels * sizeof(short));
			output_buffer.erase(output_buffer.begin(), output_buffer.begin() + sampleCount * channels);
		}

	}

	//Drops the buffered audio of the previous transmission. Call on the thread that runs process.
	void resetStateIfNewTransmission(uint32_t stateGeneration)
	{
		if (!stateReset.shouldReset(stateGeneration)) return;
		input_buffer.clear();
		output_buffer.clear();
		hrft = std::make_unique<clunk::Hrtf>(); //its overlap and pending output belong to the old audio too (Hrtf is not assignable)
	}

	~Clunk()
	{
		input_buffer.clear();
		output_buffer.clear();
	}


private:
	std::unique_ptr<clunk::Hrtf> hrft = std::make_unique<clunk::Hrtf>();
	clunk::Buffer dst_buffer;
	EffectStateResetTracker stateReset;
	std::vector<short> input_buffer;
	std::vector<short> output_buffer;
};
