class_name ThrusterAudio
extends AudioStreamPlayer

const MIX_RATE: float = 22050.0

var _playback: AudioStreamGeneratorPlayback
var _target_intensity: float = 0.0
var _intensity: float = 0.0
var _low_phase: float = 0.0
var _whine_phase: float = 0.0
var _pulse_phase: float = 0.0


func _ready() -> void:
    var generator := AudioStreamGenerator.new()
    generator.mix_rate = MIX_RATE
    generator.buffer_length = 0.14
    stream = generator
    volume_db = -7.0
    play()
    _playback = get_stream_playback() as AudioStreamGeneratorPlayback
    _fill_buffer()


func set_intensity(value: float) -> void:
    _target_intensity = clampf(value, 0.0, 1.0)


func _process(delta: float) -> void:
    var response := 1.0 - exp(-8.0 * delta)
    _intensity = lerpf(_intensity, _target_intensity, response)
    _fill_buffer()


func _fill_buffer() -> void:
    if _playback == null:
        return

    var frames_available := _playback.get_frames_available()
    var fundamental_hz := lerpf(38.0, 102.0, _intensity)
    var whine_hz := lerpf(150.0, 470.0, _intensity)
    var pulse_hz := lerpf(7.0, 18.0, _intensity)
    var amplitude := lerpf(0.012, 0.22, _intensity)

    for _frame: int in range(frames_available):
        _low_phase = fmod(_low_phase + fundamental_hz / MIX_RATE, 1.0)
        _whine_phase = fmod(_whine_phase + whine_hz / MIX_RATE, 1.0)
        _pulse_phase = fmod(_pulse_phase + pulse_hz / MIX_RATE, 1.0)

        var pulse := 0.88 + 0.12 * sin(_pulse_phase * TAU)
        var sample := (
            sin(_low_phase * TAU) * 0.70
            + sin(_whine_phase * TAU) * 0.22
            + sin(_low_phase * TAU * 2.0) * 0.08
        ) * amplitude * pulse
        sample = clampf(sample, -0.85, 0.85)
        _playback.push_frame(Vector2(sample, sample))
