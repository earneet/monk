extends GutTest

func _all_level_paths() -> Array:
    var dir := DirAccess.open("res://resources/levels")
    assert_not_null(dir, "无法打开 resources/levels")
    var paths: Array = []
    dir.list_dir_begin()
    var entry := dir.get_next()
    while entry != "":
        if entry.ends_with(".tres"):
            paths.append("res://resources/levels/" + entry)
        entry = dir.get_next()
    dir.list_dir_end()
    return paths

func test_all_levels_validate_clean():
    var paths := _all_level_paths()
    assert_true(paths.size() > 0, "levels 目录应为非空")
    for path in paths:
        var lr := load(path) as LevelResource
        assert_not_null(lr, "加载失败: %s" % path)
        var ls := LevelSystem.new()
        var errs := ls.validate(lr)
        assert_eq(errs, [], "校验出错 %s: %s" % [path, errs])
