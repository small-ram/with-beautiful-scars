extends SceneTree

class WomanPhoto:
    signal all_words_transformed
    var _labels : Array = []
    var _transformed : PackedByteArray

    func _init(count:int):
        _transformed = PackedByteArray()
        _transformed.resize(count)
        for i in range(count):
            _labels.append(Label.new())

    func _transform_phrase(idx:int) -> void:
        if idx < 0 or idx >= _labels.size() or _transformed[idx]:
            return
        _transformed[idx] = 1
        if _transformed.count(0) == 0:
            all_words_transformed.emit()

func _init():
    var wp = WomanPhoto.new(2)
    var emit_count := [0]
    wp.all_words_transformed.connect(func(): emit_count[0] += 1)

    wp._transform_phrase(0)
    assert(emit_count[0] == 0)
    wp._transform_phrase(1)
    assert(emit_count[0] == 1)

    quit()
