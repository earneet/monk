extends GutTest

func test_ready_safe_without_chapter_files():
    var boot := Boot.new()
    boot.chapter_paths = ["res://resources/chapters/__nonexistent__.tres"]
    boot.layout_path = "res://resources/menu/__nonexistent__.tres"
    add_child_autofree(boot)
    assert_not_null(boot._progression)
    assert_eq(boot._chapters.size(), 0)

func test_level_instance_cleaned_on_exit():
    var boot := Boot.new()
    add_child_autofree(boot)
    boot._exit_level()
    assert_true(boot._level_instance == null)
