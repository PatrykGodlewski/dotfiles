# Functions shared by bash and zsh — sourced by ~/.bashrc and ~/.zshrc.

# crop <input> [output]: cut a 1920x880 strip (y=200) out of a video
crop() {
	local input_file="$1"
	local output_file="${2:-cropped_output.mp4}"
	if [ -z "$input_file" ]; then
		echo "Usage: crop input_file [output_file]"
		return 1
	fi
	if [ ! -f "$input_file" ]; then
		echo "Error: '$input_file' not found"
		return 1
	fi
	ffmpeg -i "$input_file" -vf "crop=1920:880:0:200" -c:a copy "$output_file" &&
		echo "Cropped video saved as $output_file"
}

# tkosmo: major updates for the @kosmo packages
tkosmo() {
	taze major -r -l -n @kosmo\*
}
