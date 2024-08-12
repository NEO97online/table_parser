LOOT_TABLE_STRING :: #string DONE
chance      item_id         quantity    drop_message
==SERAPHIM
0.01        HEAVENSWORD     1           "The skies open as a glistening blade falls to the earth."
0.1         ANGEL_WING      1           ""
0.5         GOLD            1000        ""
==GOBLIN
1.0         GOBLIN_BONES    1           ""
0.5         GOLD            50          ""
0.2         GEM             1           "A shimmering gem that the goblin stole falls out of his pocket."
DONE

SPAWN_TABLE_STRING :: #string DONE
delay       enemy
==
10          GOBLIN
20          SERAPHIM
==
0           GOBLIN
1           GOBLIN
2           GOBLIN
3           GOBLIN
DONE

LootData :: struct {
    chance: float;
    item_id: ItemId;
    quantity: int;
    drop_message: string;
}

EnemyId :: enum {
    SERAPHIM;
    GOBLIN;
}

ItemId :: enum {
    HEAVENSWORD;
    ANGEL_WING;
    GOLD;
    GOBLIN_BONES;
    GEM;
}

SpawnData :: struct {
    delay: float;
    enemy: EnemyId;
}

main :: () {
    // The loot table is keyed by EnemyId, i.e. `loot_table[EnemyId.GOBLIN][2]`
    loot_table_res := load_tbl_string(LOOT_TABLE_STRING, LootData, EnemyId);
    assert(loot_table_res.success, loot_table_res.error_message);
    loot_table := loot_table_res.data;

    // The spawn table has no enum key, so it is just sequential, i.e. `spawn_table[5][2]`
    spawn_table_res := load_tbl_string(SPAWN_TABLE_STRING, SpawnData);
    assert(spawn_table_res.success, spawn_table_res.error_message);
    spawn_table := spawn_table_res.data;

    print("loot table:\n%\n", loot_table);
    print("spawn table:\n%\n", spawn_table);
}

#import,file "./module.jai";

#import "Basic";
