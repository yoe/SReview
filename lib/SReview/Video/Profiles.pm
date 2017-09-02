package SReview::Video::Profiles

my $profiles = {
	vp8 => {
		vcodec => "libvpx",
		acodec => "libvorbis",
		settings => {
			preview => {
				"320x240p30" => {
					bitrate => 150,
					quality => 63,
				},
			},
			sreview => {
				"1280x720p30" => {
					bitrate => 1024,
					quality => 10,
				},
				"1280x720p60" => {
					bitrate => 1800,
					quality => 10,
				},
			},
		},
	},
	vp9 => {
		vcodec => "libvpx-vp9",
		acodec => "opus",
		settings => {
			# From https://developers.google.com/media/vp9/settings/vod
			google => {
				"320x240p30" => {
					bitrate => 150,
					quality => 37,
					sp_speed => 1,
				},
				"640x360p30" => {
					bitrate => 276,
					quality => 36,
					sp_speed => 1,
				},
				"640x480p30" => {
					bitrate => 750,
					quality => 33,
					sp_speed => 1,
				},
				"1280x720p30" => {
					bitrate => 1024,
					quality => 32,
					sp_speed => 2,
				},
				"1280x720p60" => {
					bitrate => 1800,
					quality => 32,
					sp_speed => 2,
				},
				"1920x1080p30" => {
					bitrate => 1800,
					quality => 31,
					sp_speed => 2,
				},
				"1920x1080p60" => {
					bitrate => 3000,
					quality => 31,
					sp_speed => 2,
				},
				"2560x1440p30" => {
					bitrate => 6000,
					quality => 24,
					sp_speed => 2,
				},
				"2560x1440p60" => {
					bitrate => 9000,
					quality => 24,
					sp_speed => 2,
				},
				"3840x2160p30" => {
					bitrate => 12000,
					quality => 15,
					sp_speed => 2,
				},
				"3840x2160p60" => {
					bitrate => 18000,
					quality => 15,
					sp_speed => 2,
				},
			},
		},
	},
};
