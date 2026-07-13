extends GutTest

const LEVEL_FILES := ["l1_1", "l1_2", "l1_3", "l1_4", "l1_5", "l2_1", "l2_2", "l2_3"]
const EXPECTED_IDS := ["1-1", "1-2", "1-3", "1-4", "1-5", "2-1", "2-2", "2-3"]
const EXPECTED_NAMES := ["初扫", "石径", "曲径", "溪畔", "前院终", "叩门", "重门", "后山终"]

func test_all_levels_exist_with_correct_meta() -> void:
    for i in range(LEVEL_FILES.size()):
        var p := "res://resources/levels/%s.tres" % LEVEL_FILES[i]
        assert_true(ResourceLoader.exists(p), "关卡应存在: %s" % p)
        var lr := load(p) as LevelResource
        assert_not_null(lr, "加载失败: %s" % p)
        assert_eq(lr.meta.id, EXPECTED_IDS[i], "meta.id %s" % p)
        assert_eq(lr.meta.display_name, EXPECTED_NAMES[i], "display_name %s" % p)
        assert_eq(lr.meta.difficulty, i + 1, "difficulty 应递增 %s" % p)

func test_chapter_refs() -> void:
    var ch1 := load("res://resources/chapters/chapter_01.tres") as ChapterResource
    assert_not_null(ch1, "chapter_01 应存在")
    assert_eq(ch1.id, "ch1")
    assert_eq(ch1.display_name, "前院")
    assert_eq(ch1.main_levels.size(), 5, "chapter_01 应有 5 关")
    for i in range(5):
        assert_eq((ch1.main_levels[i] as LevelResource).meta.id, EXPECTED_IDS[i], "ch1 第 %d 关 id" % i)
    var ch2 := load("res://resources/chapters/chapter_02.tres") as ChapterResource
    assert_not_null(ch2, "chapter_02 应存在")
    assert_eq(ch2.id, "ch2")
    assert_eq(ch2.display_name, "后山")
    assert_eq(ch2.main_levels.size(), 3, "chapter_02 应有 3 关")
    for i in range(3):
        assert_eq((ch2.main_levels[i] as LevelResource).meta.id, EXPECTED_IDS[5 + i], "ch2 第 %d 关 id" % i)

func test_mechanic_levels_have_lever_and_door() -> void:
    var door_files := ["l2_1", "l2_2", "l2_3"]
    var expected_doors := [1, 2, 1]
    for i in range(door_files.size()):
        var lr := load("res://resources/levels/%s.tres" % door_files[i]) as LevelResource
        assert_not_null(lr, "%s 应存在" % door_files[i])
        var levers := 0
        var doors := 0
        for m in lr.mechanics:
            if m is LeverData:
                levers += 1
            elif m is DoorData:
                doors += 1
        assert_eq(doors, expected_doors[i], "%s 门数" % door_files[i])
        assert_eq(levers, expected_doors[i], "%s 机关数" % door_files[i])
