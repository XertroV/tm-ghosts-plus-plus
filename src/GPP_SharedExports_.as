namespace Ghosts_PP {
    shared interface IInputChange {
        int32 get_Tick();
        uint64 get_States();
        uint16 get_MouseAccuX();
        uint16 get_MouseAccuY();
        int8 get_Steer();
        bool get_Gas();
        bool get_Brake();
        bool get_Horn();
        uint8 get_CharacterStates();
        int64 get_Time();
        bool get_FreeLook();
        bool get_ActionSlot1();
        bool get_ActionSlot2();
        bool get_ActionSlot3();
        bool get_ActionSlot4();
        bool get_ActionSlot5();
        bool get_ActionSlot6();
        bool get_ActionSlot7();
        bool get_ActionSlot8();
        bool get_ActionSlot9();
        bool get_ActionSlot0();
        bool get_Respawn();
        bool get_SecondaryRespawn();
        string ToString();
    }

    shared class CheckpointIxTime {
        uint32 CheckpointIndex;
        int64 Time;

        CheckpointIxTime(uint ix, int64 t) {
            CheckpointIndex = ix;
            Time = t;
        }
    }
}
