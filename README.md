* [Issue](#issue)
* [Mod](#mod)
    * [How to reproduce issue](#how_to_reproduce_issue)
* [Investigation](#investigation)

***
# Issue

Game crashes after some long perod of intence gaming (~30-40 min).

```
EXCEPTION_ACCESS_VIOLATION (0xc0000005) at address 0x0095854f
attempted to write memory at 0x028d1980
```

[This issue on github](https://github.com/FAForever/fa/issues/1445)

***
# Mod
This Forged Alliance mod deisgned to help to reproduce this issue solo. This issue reproduction requires very intence and lont time game process which cannot be easy achiaved without involving of other players. Mod helps. It designed to force game engine to allocate more and more memory buffers for game resources. Note: 3d models of reclaim (after unit killing) have impact on memory usage (more diverse reclaim on filed -> more memory usage).

Mod provides an endless units spawning procedure. Spawn units of different types. Spawn units for each army in game.  And during unit spawning number of spawned unit types is growing. Max unit diversity on 5000+ spawned units.

## Mod installation
Mod installation procedure is trivial. Same as for other mods.
Unpack/checkout mod directory "0x0095854f" to "C:\Users\%USERNAME%\Documents\My Games\Gas Powered Games\Supreme Commander Forged Alliance\Mods\" directory.

## How to reproduce issue
### Dirty way
0. Install mod
1. Run FAF-offilne with `nobugreport` argument:
> Example:\
 C:\ProgramData\FAForever\bin\ForgedAlliance.exe /log C:\ProgramData\FAForever\logs\game.offline.log /nobugreport
2. In "Options->Video" choose windowed mode.
3. Start Windows Task Manager.
4. Start 'Skirmish' game:
    * Choose huge map for 10+ armies (e.g. "Dual Gap")
    * activate '0x0095854f' in mod manager
    * set 'Victory condition' option 'Sandbox'
    * set 'Cheating' option 'On'
    * Fill all slots with some AI
5. Activate mod spawn function by key combination (Ctrl+F12 by default, but you may (re)assign it in Menu->Key Bindings->0x0095854f). To stop unit spawning use the same key combination.
6. Move mouse pointer over center of map and spawn-spawn-spawn units until crash accured.
    * Keep claim. It takes few minutes.
    * Continue even if game speed is -10
    * Goal is reach ForgedAlliance.exe RAM usage about 2.3 GB.
    * You may sometimes stop spawning and let units to kill each other. More reclaim on map -> you closer to game crash. But spawn pauses may lead to memory usage reduction.
### Clean way
> **FIND OUT**
***
# Investigation

Crash caused by instruction at address 0x0095854f when this insctruction attempt to access (write) memory which was not allocated by process. Each time destination memory address is different.

First assumption: bug in some memory management logic. Invalid buffer size/offset calculation or some race condition.

## Disasembling and decompiling

Executable "C:\ProgramData\FAForever\bin\ForgedAlliance.exe"

At address 0x0095854f in ForgedAlliance.exe asm instruction
`rep stosd` what mean set some value to memory repeatly. Some memset().

This instruction calls sometimes (not so often) when loading of some recources (unit textures/scripts) requred.

I assume that this function is a part of main resource management mechanism. And this function allocate and prepare new huge memory blocks to place game resources such as models/textures/scripts/sounds. I assume that this function allocates new memory block each time when previus allocated is filled up. And each new allocated block have bigger size than previus (some common "optimization").

## Details
Dirty decompiled code around this instruction address:
```cpp
Function starts at 0x00958400
...
    eax14 = fun_9589e0(ecx, 40, 0);
...
while (1) {
    ...
    if (!edi15) {
        ...
    } else {
        // some structure fill
		*reinterpret_cast<void***>(edi15 + 8) = esi23;
		*reinterpret_cast<void***>(edi15) = reinterpret_cast<void**>(0);
		*reinterpret_cast<void***>(edi15 + 4) = ebp24;
		*reinterpret_cast<void***>(edi15 + 12) = ecx29;
		*reinterpret_cast<void***>(edi15 + 16) = reinterpret_cast<void**>(0);
		*reinterpret_cast<void***>(edi15 + 20) = reinterpret_cast<void**>(0);
		*reinterpret_cast<void***>(edi15 + 24) = reinterpret_cast<void**>(0);
		if (reinterpret_cast<unsigned char>(ecx29) > reinterpret_cast<unsigned char>(0)) {
			edx50 = g_pData;
			eax51 = edi15;
			edi52 = edx50 + (reinterpret_cast<unsigned char>(esi23) >> 12) * 4;
// ==>
// [0x0095854f] asm: rep stosd
			while (ecx29) {
				--ecx29;
				*edi52 = eax51;
				edi52 = edi52 + 4;
			}
// <==
		}
		fun_9580d0(ecx29, v12);
		return 1;
	}
    ...
```

This functio and related functions opearte memory blocks what allocates by special rules.
First of all there is some basic init function (and related global variables):
```cpp
// [DEBUG] 0x00F8EDA4: 01
signed char g_f8eda4 = 0;

// [DEBUG] 0x00F8ED88: ff ff ff ff ff ff ff ff 00 00 00 00 00 00 00 00 00 00 00 00 a0 0f 00 00 00 00 00 00 01 00 00 00
CRITICAL_SECTION g_f8ed88 = { 0 };

// [DEBUG] 0x00F8EDA0: 00 00 00 00
uint32_t g_f8eda0 = 0;

void x_init(signed char* arg1, void* arg2)
{
	//957e01 : push dword 0xfa0
	//957e06 : push dword 0xf8ed88
	//957e0b : call dword[0xc0f458]
	::InitializeCriticalSectionAndSpinCount(&g_f8ed88, 4000);

	//957e11 : push dword 0xf8ed88
	//957e16 : call dword[0xc0f464]
	::EnterCriticalSection(&g_f8ed88);

	//957e1c : mov ecx, [0xf8eda0]
	//957e22 : mov eax, [esp + 0x8]
	//957e26 : mov esi, [0xc0f45c]
	//957e2c : push 0x4
	//957e2e : or ecx, 0x1000
	//957e34 : push ecx
	//957e35 : push dword 0x300000
	//957e3a : push 0x0
	//957e3c : mov byte[eax], 0x1
	*arg1 = 1;
	//957e3f : mov byte[0xf8eda4], 0x1
	g_f8eda4 = 1;
	//957e46 : call esi
	gf8edc4 = ::VirtualAlloc(
		0 /* NULL */,
		0x300000, // ~3MByte
		gf8eda0 | 0x1000 /* MEM_COMMIT */,
		4 /* PAGE_READWRITE */
	);
	
	//957e48 : mov edx, [0xf8eda0]
	//957e4e : push 0x4
	//957e50 : or edx, 0x2000
	//957e56 : push edx
	//957e57 : push dword 0x20000000
	//957e5c : push 0x0
	//957e5e : mov[0xf8edc4], eax
	//957e63 : call esi
	gf8edbc = VirtualAlloc(
		0 /* NULL */,
		0x20000000, // ~500 MByte
		gf8eda0 | 0x2000 /* MEM_RESERVE */,
		4 /* PAGE_READWRITE */
	);
	
	//957e65 : push 0x1
	//957e67 : push 0x28
	//957e69 : mov[0xf8edbc], eax
	//957e6e : mov dword[0xf8edc0], 0x0
	//957e78 : mov dword[0xf8eda8], 0x20000000
	//957e82 : call dword 0x9589e0
	g_f8edc0 = 0;
	g_f8eda8 = 0x20000000;
	g_f8f32c = fun_9589e0(40, 1);

	//957e87 : add esp, 0x8
	//957e8a : mov[0xf8f32c], eax
	//957e8f : pop esi
	//957e90 : ret
	return;
}
```
Here allocates and reserves some memory blocks.
And after there a bunch of memory block size/offset calculation and memory allocation function which is unclear (<- fun_9589e0() <- fun_957c30()). Probably, this function takes buffer sizes from global predefined table, and this size used for memory allocation and fill leads to crash.
```cpp
// [DEBUG] table starts at 0xd498f0
// 0x00D498F0  04 00 00 00 08 00 00 00 0c 00 00 00 10 00 00 00 14 00 00 00 18 00 00 00 1c 00 00 00 20 00 00 00
// 0x00D49910  28 00 00 00 30 00 00 00 38 00 00 00 40 00 00 00 50 00 00 00 60 00 00 00 70 00 00 00 80 00 00 00
// 0x00D49930  a0 00 00 00 c0 00 00 00 e0 00 00 00 00 01 00 00 40 01 00 00 80 01 00 00 c0 01 00 00 00 02 00 00
// 0x00D49950  80 02 00 00 00 03 00 00 80 03 00 00 00 04 00 00 00 05 00 00 00 06 00 00 00 07 00 00 00 08 00 00
// 0x00D49970  00 0a 00 00 00 0c 00 00 00 0e 00 00 00 10 00 00 00 14 00 00 00 18 00 00 00 1c 00 00 00 20 00 00
// 0x00D49990  00 28 00 00 00 30 00 00 00 38 00 00 00 40 00 00 60 07 00 00 00 08 50 00 00 08 10 00 14 08 73 00
// 0x00D499B0  12 07 1f 00 00 08 70 00 00 08 30 00 00 09 c0 00 10 07 0a 00 00 08 60 00 00 08 20 00 00 09 a0 00
// 0x00D499D0  00 08 00 00 00 08 80 00 00 08 40 00 00 09 e0 00 10 07 06 00 00 08 58 00 00 08 18 00 00 09 90 00
// 0x00D499F0  13 07 3b 00 00 08 78 00 00 08 38 00 00 09 d0 00 11 07 11 00 00 08 68 00 00 08 28 00 00 09 b0 00
// ...
int32_t g_d498f0[] = {
	0x4000000,
	0x8000000,
	0xc000000,
	0x10000000,
	0x14000000,
	0x18000000,
	0x1c000000,
	0x20000000,
	0x28000000,
	0x30000000,
	0x38000000,
	0x40000000,
	0x50000000,
	0x60000000,
	0x70000000,
	0x80000000,
	0xa0000000,
	0xc0000000,
	0xe0000000
}

void** fun_957c30(...)
{
	int32_t x = 0; //?
	int32_t y = 0; //?
	int23_t z = 0; //? 

	unsigned char n = 0;
	unsigned char e = 44;
	do
	{
		unsigned char sign = x < 0 ? 1 : 0; //?
		x = (n + e - sign) / 2;
		if (y >= g_d498f0[x])
		{
			if (z <= g_d498f0[x])
			{
				break;
			}
			n = x + 1;
		}
		else
		{
			e = x;
		}
	} while (n < e);

	return n
}

...

void** fun_9589e0(void** ecx, int32_t a2, void** a3)
{
	void** v4;
	void** edi5;
	void** ebx6;
	void** eax7;

	v4 = a3;
	eax7 = fun_957c30(1, v4, edi5, ebx6);
	fun_9587e0(ecx, eax7, 1, *reinterpret_cast<signed char*>(&v4), edi5);
	return 0;
}
```
