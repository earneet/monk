extends GutTest

func test_ready_safe_without_chapter_files():
    var boot := Boot.new()
    add_child(boot)
    assert_not_null(boot._progression)
    assert_eq(boot._chapters, [])

func test_level_instance_cleaned_on_exit():
    var boot := Boot.new()
    add_child(boot)
    boot._exit_level()
    assert_true(boot._level_instance == null)
