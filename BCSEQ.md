# BCSEQ.md

# Nintendo 3DS BCSEQ / CSEQ — 逆向资料与实现参考

> 资料整理日期：2026-11-03  
> 目标：为 LLM 或开发者实现 Nintendo 3DS BCSEQ 解析器、反汇编器、音序解释器及音频渲染器提供可靠的公开资料入口。  
> 范围：NintendoWare for CTR（NW4C）音频系统，重点为 `BCSEQ` / `CSEQ`，并覆盖必要的 `BCSAR`、`BCBNK`、`BCWAR`、`BCWAV` 和 3DS DSP 背景。

---

## 0. 阅读须知

### 0.1 术语

| 名称 | Magic | 用途 |
|---|---|---|
| BCSEQ | `CSEQ` | 音序文件，包含事件指令和标签 |
| BCSAR | `CSAR` | 声音档案，组织声音条目及相关资源 |
| BCBNK | `CBNK` | 乐器音色库，定义音符和力度区域及波形引用 |
| BCWAR | `CWAR` | 波形档案 |
| BCWAV | `CWAV` | 具体波形和采样数据 |
| BCWSD | `CWSD` | Wave Sound Data 描述信息，并非音频编码格式 |
| BCSTM | `CSTM` | 流式音频，与 BCSEQ 不同 |

**重要：BCSEQ 是音序，不是已经混好的 PCM 音频。**

完整播放通常需要：

`BCSAR 声音条目 → BCSEQ → BCBNK → BCWAR → BCWAV → 音序解释器 / Voice 管理器 → 音频混音器`

BCSEQ 可以控制音符、时序、音量、声像、音高、包络、调制等，但它本身不包含完整的乐器波形，也不决定所有混音效果的具体算法。

### 0.2 证据等级

- **A：源码直接证据**。实际解析器、转换器、音序解释器中的实现。
- **B：结构文档**。公开的文件格式逆向文档。
- **C：社区经验**。论坛、工具说明、示例流程。
- **D：跨平台参考**。BFSEQ、SSEQ 等近亲格式，只可用于比较，不能直接认定 BCSEQ 相同。

特别注意：GotaSequenceLib 的 `CtrCafe.cs` **同时服务于 3DS 和 Wii U**。其中的完整 Opcode 映射不能单凭这一个文件就证明所有指令在每个 3DS 游戏和每个 NW4C 版本中均可用。

---

## 1. 必须首先阅读的资料

| 优先级 | 资料 | 证据 | 用途 |
|---|---|---|---|
| P0 | [Citric Composer — Sequences](https://gota7.github.io/Citric-Composer/specs/seq.html) | B | BCSEQ 文件头、DATA、LABL、标签 |
| P0 | [Citric Composer — Common Structures](https://gota7.github.io/Citric-Composer/specs/common.html) | B | 字节序、版本、引用、文件头 |
| P0 | [GotaSequenceLib — CtrCafe.cs](https://github.com/Gota7/GotaSequenceLib/blob/master/CtrCafe.cs) | A | 3DS/Wii U Opcode 字节映射 |
| P0 | [GotaSequenceLib — SequenceCommand.cs](https://github.com/Gota7/GotaSequenceLib/blob/master/SequenceCommand.cs) | A | 指令参数读取、写入 |
| P0 | [GotaSequenceLib — SequenceFile.cs](https://github.com/Gota7/GotaSequenceLib/blob/master/SequenceFile.cs) | A | 指令流解析、标签和跳转目标 |
| P0 | [SequenceConvert — BXSEQ.cs](https://github.com/Gota7/SequenceConvert/blob/master/BXSEQ.cs) | A | CSEQ 容器读写 |
| P0 | [DualRip](https://github.com/TetraSsky/DualRip) | A | 独立的 3DS CSEQ 软件解释和渲染实现 |
| P1 | [3dbrew — BCSAR](https://www.3dbrew.org/wiki/BCSAR) | B | 声音档案和关联资源 |
| P1 | [Citric Composer — Banks](https://gota7.github.io/Citric-Composer/specs/bnk.html) | B | BCBNK 乐器映射 |
| P1 | [Citric Composer — Wave Archives](https://gota7.github.io/Citric-Composer/specs/war.html) | B | BCWAR 波形档案 |
| P1 | [3dbrew — DSP Memory Region](https://www.3dbrew.org/wiki/DSP_Memory_Region) | B | 3DS DSP Voice、采样与混音 |
| P1 | [soneek — 3DSUSoundArchiveTool](https://github.com/soneek/3DSUSoundArchiveTool) | A | BCSAR、序列、音色库提取 |
| P1 | [kr3nshaw — caesar](https://github.com/kr3nshaw/caesar) | A | 另一套声音档案提取实现 |
| P2 | [HCS64 — cseq2mid 讨论](https://www.hcs64.com/mboard/forum.php?showthread=56433) | C | 早期 BCSEQ 逆向和 MIDI 转换问题 |

建议先阅读 P0，再进入 P1。不要先根据 MIDI 或 SSEQ 的结构猜测 BCSEQ。

---

## 2. BCSEQ 文件结构

主要依据：

- https://gota7.github.io/Citric-Composer/specs/seq.html
- https://gota7.github.io/Citric-Composer/specs/common.html
- https://github.com/Gota7/SequenceConvert/blob/master/BXSEQ.cs

### 2.1 顶层结构

BCSEQ 文件的 Magic 是 `CSEQ`，包含两个主要块：

```text
BCSEQ / CSEQ
├── FileHeader
│   ├── Magic = "CSEQ"
│   ├── BOM / Byte order
│   ├── Header size
│   ├── Version
│   ├── File size
│   ├── Block count = 2
│   └── Block references
├── DATA
│   └── Raw sequence instruction stream
└── LABL
    ├── Label reference table
    └── Label entries
        ├── Sequence-data offset
        └── Label name
```

块的引用类型：

| 块 | Magic | Reference Type |
|---|---|---|
| 音序数据 | `DATA` | `0x5000` |
| 标签 | `LABL` | `0x5001` |
| 标签表中的标签引用 | — | `0x5100` |
| 标签内指向序列数据的引用 | — | `0x1F00` |

### 2.2 文件头

根据 Citric Composer 的通用文件头文档：

| 偏移 | 类型 | 内容 |
|---|---|---|
| `0x00` | char[4] | `CSEQ` |
| `0x04` | u16 | BOM |
| `0x06` | u16 | 文件头大小 |
| `0x08` | u32 | 版本 |
| `0x0C` | u32 | 文件总大小 |
| `0x10` | u16 | 块数量 |
| `0x12` | u16 | 对齐保留 |
| `0x14` | SizedReference[] | 块引用 |

对 `C` 型文件，文档给出的版本表示是读取后的 `0xMMIIRR00`，分别表示 major、minor、revision。

**不要将 BFSEQ 的 `F` 型版本字段布局直接套用到 BCSEQ。**

3DS 的序列数据使用大端序。实际实现仍应读取并校验 BOM，而不是忽略文件头。

### 2.3 DATA

`DATA` 块头：

```text
+0x00  char[4]  "DATA"
+0x04  u32      Block size
+0x08  byte[]   Sequence instruction stream
```

原始音序数据是连续的字节码。

需要严格区分：

1. 文件绝对偏移。
2. DATA 块起始偏移。
3. DATA 块内容起始偏移。
4. 指令流内部偏移。

跳转和标签目标应按相应解析器的约定解释，不能把它们直接当作文件绝对偏移。

### 2.4 LABL

`LABL` 块保存可命名的音序入口点和跳转位置。

标签包含：

- 指向序列数据的 Reference。
- 标签名称长度。
- 标签名称及终止符。
- 必要的对齐填充。

标签数据通常按 4 字节对齐；块级数据通常按 0x20 字节对齐。

源码：

- https://github.com/Gota7/SequenceConvert/blob/master/BXSEQ.cs

**实现提醒：**源码中的某些简化读取方法可能会移除 DATA 末尾的零字节。编写自己的解析器时，必须区分实际填充和合法的 `0x00` 数据，不要无条件删除尾部零字节。

本仓库的容器 reader 将 DATA／LABL 保留为独立 raw body，不在读取 DATA 时定位 LABL。`nintendo-ware:xseq-events` 按文件 magic/BOM 选择事件布局，建立事件边界索引后才解析标签；开轨、跳转、调用和标签均返回同一事件向量的索引。内部 `nintendo-ware::xseq-label-entries` 取得标签，`xseq-labels` 只查找 LABL section。坏 opcode、截断和非指令边界目标在提取时报告，单独读取容器不执行音序解析或播放。

---

## 3. Opcode 映射索引

**本节是从 GotaSequenceLib 的 `CtrCafe.cs` 整理的源码映射索引，不是经过全部真实 3DS 游戏逐项验证的官方指令规范。**

主要来源：

https://github.com/Gota7/GotaSequenceLib/blob/master/CtrCafe.cs

完整参数类型和字节布局请继续阅读：

- https://github.com/Gota7/GotaSequenceLib/blob/master/SequenceCommand.cs
- https://github.com/Gota7/GotaSequenceLib/blob/master/SequenceCommands.cs
- https://github.com/Gota7/GotaSequenceLib/blob/master/SequenceFile.cs

### 3.1 基础音符、流程和前缀指令

| Opcode | 源码名称 | 说明 |
|---|---|---|
| `0x00–0x7F` | Note | 音符编号由 Opcode 自身表示 |
| `0x80` | Wait | 等待指定 Tick |
| `0x81` | ProgramChange | 切换乐器 |
| `0x88` | OpenTrack | 启动其他轨道 |
| `0x89` | Jump | 跳转 |
| `0x8A` | Call | 调用子程序 |
| `0xA0` | Random | 随机参数包装 |
| `0xA1` | Variable | 变量参数包装 |
| `0xA2` | If | 条件执行包装 |
| `0xA3` | Time | 时间参数包装 |
| `0xA4` | TimeRandom | 随机时间参数包装 |
| `0xA5` | TimeVariable | 变量时间参数包装 |

`0xA0–0xA5` 应作为带有嵌套指令或参数修饰语义的结构处理，而不是简单地将后续字节当作普通独立事件。

源码还提供了 `RandomParameter.cs`、`VariableParameter.cs`、`TimeParameter.cs` 等类：

- https://github.com/Gota7/GotaSequenceLib/blob/master/RandomParameter.cs
- https://github.com/Gota7/GotaSequenceLib/blob/master/VariableParameter.cs
- https://github.com/Gota7/GotaSequenceLib/blob/master/TimeParameter.cs
- https://github.com/Gota7/GotaSequenceLib/blob/master/OpenTrackParameter.cs

### 3.2 轨道配置和音色处理

| Opcode | 源码名称 |
|---|---|
| `0xB0` | Timebase |
| `0xB1` | EnvHold |
| `0xB2` | Monophonic |
| `0xB3` | VelocityRange |
| `0xB4` | BiquadType |
| `0xB5` | BiquadValue |
| `0xB6` | BankSelect |
| `0xBD` | ModPhase |
| `0xBE` | ModCurve |
| `0xBF` | FrontBypass |

这组指令中部分涉及滤波、调制和输出路由。**它们在共享的 CTR/Cafe Opcode 映射中出现，不等于每个 3DS NW4C 版本均实现相同的行为。**

### 3.3 音量、声像、音高和调制

| Opcode | 源码名称 |
|---|---|
| `0xC0` | Pan |
| `0xC1` | Volume |
| `0xC2` | MainVolume |
| `0xC3` | Transpose |
| `0xC4` | PitchBend |
| `0xC5` | BendRange |
| `0xC6` | Prio |
| `0xC7` | NoteWait |
| `0xC8` | Tie |
| `0xC9` | Porta |
| `0xCA` | ModDepth |
| `0xCB` | ModSpeed |
| `0xCC` | ModType |
| `0xCD` | ModRange |
| `0xCE` | PortaSw |
| `0xCF` | PortaTime |

注意：

- `NoteWait` 影响音符与轨道时间推进的关系。
- `Tie` 影响音符之间的连接、重新触发和包络行为。
- `Portamento` 不能简单转换成两个 MIDI Note On。
- `PitchBend` 的原始值和最终音高变化需要结合 `BendRange`。
- `Volume`、`MainVolume` 和其他增益层次不应全部合并为同一个参数。

### 3.4 包络、循环和混音控制

| Opcode | 源码名称 |
|---|---|
| `0xD0` | Attack |
| `0xD1` | Decay |
| `0xD2` | Sustain |
| `0xD3` | Release |
| `0xD4` | LoopStart |
| `0xD5` | Volume2 |
| `0xD6` | PrintVar |
| `0xD7` | SurroundPan |
| `0xD8` | LpfCutoff |
| `0xD9` | FxSendA |
| `0xDA` | FxSendB |
| `0xDB` | MainSend |
| `0xDC` | InitPan |
| `0xDD` | Mute |
| `0xDE` | FxSendC |
| `0xDF` | Damper |

这些指令涉及两种不同的实现层：

1. 音序解释器更新轨道或音符的控制状态。
2. Voice / DSP / 软件混音器将状态转化为实际采样播放和混音参数。

`FxSendA/B/C` 代表发送控制，不意味着 BCSEQ 文件自身定义了 Reverb、Chorus 或其他效果器算法。

### 3.5 时间、扩展指令和终止

| Opcode | 源码名称 |
|---|---|
| `0xE0` | ModDelay |
| `0xE1` | Tempo |
| `0xE3` | SweepPitch |
| `0xE4` | ModPeriod |
| `0xF0` | Extended |
| `0xFB` | EnvReset |
| `0xFC` | LoopEnd |
| `0xFD` | Return |
| `0xFE` | AllocateTrack |
| `0xFF` | Fin |

`0xF0` 后面还有子指令字节，必须单独解码。

不要把 `0xFF` 解释为整个 BCSEQ 文件结束；它对应当前执行轨道的终止。

---

## 4. `0xF0` 扩展指令

来源：

https://github.com/Gota7/GotaSequenceLib/blob/master/CtrCafe.cs

### 4.1 变量运算

| `0xF0` 后的子 Opcode | 源码名称 |
|---|---|
| `0x80` | SetVar |
| `0x81` | AddVar |
| `0x82` | SubVar |
| `0x83` | MulVar |
| `0x84` | DivVar |
| `0x85` | ShiftVar |
| `0x86` | RandVar |
| `0x87` | AndVar |
| `0x88` | OrVar |
| `0x89` | XorVar |
| `0x8A` | NotVar |
| `0x8B` | ModVar |

### 4.2 变量比较

| 子 Opcode | 源码名称 |
|---|---|
| `0x90` | CmpEq |
| `0x91` | CmpGe |
| `0x92` | CmpGt |
| `0x93` | CmpLe |
| `0x94` | CmpLt |
| `0x95` | CmpNe |

比较指令与条件执行状态有关。

应从解释器源码核对变量作用域、整数宽度、符号处理、除零行为、溢出行为以及条件寄存器的生命周期。

### 4.3 更多调制指令

共享映射中还存在：

| 子 Opcode 范围 | 功能 |
|---|---|
| `0xA0–0xA5` | Mod2 Curve / Phase / Depth / Speed / Type / Range |
| `0xA6–0xAB` | Mod3 Curve / Phase / Depth / Speed / Type / Range |
| `0xAC–0xB1` | Mod4 Curve / Phase / Depth / Speed / Type / Range |
| `0xE0` | UserCall |
| `0xE1–0xE2` | Mod2 Delay / Period |
| `0xE3–0xE4` | Mod3 Delay / Period |
| `0xE5–0xE6` | Mod4 Delay / Period |

**兼容性警告：**这些指令来自同时覆盖 CTR 和 Cafe 的代码。对它们在具体 3DS 游戏中的可用性，需要独立测试或核对更接近原始 3DS 驱动的实现。

---

## 5. 参数编码与时间模型

参考：

- https://github.com/Gota7/GotaSequenceLib/blob/master/SequenceCommand.cs
- https://github.com/Gota7/GotaSequenceLib/blob/master/VariableLength.cs
- https://github.com/Gota7/GotaSequenceLib/blob/master/UInt24.cs
- https://nintendo-formats.com/libs/nw/bfseq.html

在相关 NintendoWare 序列中，可变长度整数使用类似 MIDI VLQ 的编码方式：每字节低 7 位贡献数据，最高位表示后面是否继续。

参考伪代码：

```python
def read_varint(reader):
    value = 0
    while True:
        b = reader.read_u8()
        value = (value << 7) | (b & 0x7F)
        if (b & 0x80) == 0:
            return value
```

需要分别确认：

- Note 的 Velocity 和 Duration 参数。
- Wait 的 Tick 参数。
- ProgramChange 的乐器编号编码。
- Jump、Call、OpenTrack 的 24 位目标偏移。
- 16 位数值的大端解释。
- 各控制指令的 `u8`、`s8`、`u16`、`s16` 类型。
- 随机与变量包装对原指令参数编码的修改。

BFSEQ 公开文档列出 120 BPM 和 48 Tick/Beat 等默认值，但**不能只凭 BFSEQ 文档就认定所有 BCSEQ 版本完全一致**。应与 BCSEQ 的实际解释器和测试文件对照。

---

## 6. BCSAR：如何找到音序及其依赖

资料：

- https://www.3dbrew.org/wiki/BCSAR
- https://github.com/soneek/3DSUSoundArchiveTool
- https://github.com/kr3nshaw/caesar
- https://github.com/TetraSsky/DualRip

BCSAR 包含声音名称、声音条目、资源信息和文件数据。

不要假设：

- 一个声音名称一定对应一个独立的磁盘 `.bcseq` 文件。
- BCSAR 中的文件序号就是乐器 Bank 序号。
- 单独提取 BCSEQ 后就能知道其全部 Bank、Wave Archive 和 Player 配置。
- 不同游戏的 BCSAR 都采用完全相同的资源组织方式。

实现时建议先构建以下对象：

```text
SoundArchive
  ├── SoundEntry
  │   ├── SoundType
  │   ├── SequenceFileId
  │   ├── BankReferences
  │   ├── Player / Track settings
  │   └── Volume / Other playback metadata
  ├── FileTable
  ├── Banks
  ├── WaveArchives
  └── Groups
```

这只是建议的软件模型，不是官方二进制结构定义。

---

## 7. BCBNK：乐器解析

核心文档：

https://gota7.github.io/Citric-Composer/specs/bnk.html

源码：

- https://github.com/soneek/3DSUSoundArchiveTool/blob/master/BNK.h
- https://github.com/Gota7/GotaSoundIO

BCBNK 包含乐器表以及 Wave ID 映射。

文档中可见的主要结构：

```text
BCBNK / CBNK
└── INFO
    ├── Instrument reference table
    └── Wave ID table
```

乐器可通过 Direct、Range、Index 等结构选择区域；区域又可根据 Key 和 Velocity 进一步分层。

Velocity Region 可能携带：

- Wave 索引。
- Original Key。
- Volume。
- Pan / Surround Pan。
- Pitch。
- Interpolation 类型。
- ADSHR 包络数据。

**不要直接将 BCSEQ ProgramChange 的数值当作 General MIDI 音色编号。**它是 NintendoWare 乐器系统中的选择值，必须结合实际 Bank 解析。

---

## 8. BCWAR / BCWAV：采样来源

资料：

- https://gota7.github.io/Citric-Composer/specs/war.html
- https://gota7.github.io/Citric-Composer/specs/wav.html
- https://www.3dbrew.org/wiki/BCWAV
- https://github.com/soneek/3DSUSoundArchiveTool/blob/master/WAR.h
- https://github.com/soneek/3DSUSoundArchiveTool/blob/master/WAV.h

BCWAR 是波形档案，主要包含：

```text
CWAR
├── FileHeader
├── INFO
│   └── Wave references
└── FILE
    └── Embedded CWAV data
```

BCWAV 存储实际波形。

实现音频渲染时，需要正确处理采样格式、采样率、Loop Start、Loop End、ADPCM 解码状态、原始音高、重采样和声道配置。

Citric Composer 的 BCWAV 页面目前明确标为 `TODO`，不能把它当作完整的波形编码规范。

---

## 9. 3DS DSP 与混音架构

核心资料：

https://www.3dbrew.org/wiki/DSP_Memory_Region

3dbrew 文档描述的相关 DSP 固件接口包括：

- 24 个可配置输入。
- 采样率倍率和插值模式。
- PCM8、PCM16、ADPCM 缓冲格式。
- 输入增益。
- 简单滤波器与 Biquad。
- 多组中间混音总线。
- Aux / Effect 相关混音。
- Delay、Reverb 等效果配置。

**必须区分以下三件事：**

1. BCSEQ 指令可以要求修改 Pan、Pitch、ADSR、LFO、Send 等参数。
2. NintendoWare 的 CPU 端音序和 Voice 管理器需要解释这些指令、维护轨道状态并分配 Voice。
3. DSP 固件负责实际采样处理中的一部分工作，例如解码、重采样、滤波和混音。

不能据此断言 DSP 硬件原生解释 BCSEQ 指令，也不能断言完整 ADSR/LFO 状态机都在 DSP 中执行。

3dbrew 同时提醒：不同 DSP 固件版本可能有行为差异。

---

## 10. 可直接参考的开源实现

### 10.1 GotaSequenceLib

仓库：

https://github.com/Gota7/GotaSequenceLib

重点文件：

- [CtrCafe.cs](https://github.com/Gota7/GotaSequenceLib/blob/master/CtrCafe.cs)：Opcode 映射。
- [SequenceCommands.cs](https://github.com/Gota7/GotaSequenceLib/blob/master/SequenceCommands.cs)：指令枚举。
- [SequenceCommand.cs](https://github.com/Gota7/GotaSequenceLib/blob/master/SequenceCommand.cs)：指令读写。
- [SequenceFile.cs](https://github.com/Gota7/GotaSequenceLib/blob/master/SequenceFile.cs)：音序数据解析、控制流偏移、文本转换。
- [Playback/Player.cs](https://github.com/Gota7/GotaSequenceLib/blob/master/Playback/Player.cs)：播放器。
- [Playback/Track.cs](https://github.com/Gota7/GotaSequenceLib/blob/master/Playback/Track.cs)：轨道。
- [Playback/Channel.cs](https://github.com/Gota7/GotaSequenceLib/blob/master/Playback/Channel.cs)：声部处理。
- [Playback/Mixer.cs](https://github.com/Gota7/GotaSequenceLib/blob/master/Playback/Mixer.cs)：混音。
- [Playback/PlayableBank.cs](https://github.com/Gota7/GotaSequenceLib/blob/master/Playback/PlayableBank.cs)：Bank 播放适配。

这是非常适合 LLM 阅读的项目，因为它同时包含指令数据结构和播放架构。

注意检查具体实现的完整性及 GPL-3.0 许可证。

### 10.2 SequenceConvert

仓库：

https://github.com/Gota7/SequenceConvert

重点文件：

- https://github.com/Gota7/SequenceConvert/blob/master/BXSEQ.cs
- https://github.com/Gota7/SequenceConvert/blob/master/Program.cs
- https://github.com/Gota7/SequenceConvert/blob/master/README.md

支持在二进制序列和文本表示之间转换。

README 提到的相关参数：

```text
-exportLabels
-version 2.1.0
```

该工具依赖 GotaSequenceLib 和 GotaSoundIO。

注意：它不是一个保证所有 BCSEQ 都能无损转换为 MIDI 的工具。

### 10.3 DualRip

仓库：

https://github.com/TetraSsky/DualRip

README 明确说明其具有独立的 3DS CSEQ 渲染实现。

重点目录：

- `dualrip/formats/ctr/`：CSAR、CSEQ、CBNK、CWAR、CWSD、BCSTM 解析。
- `dualrip/engine/ctr/`：3DS 音序、Channel、音频渲染。
- `tests/`：测试。

适合用来对照：

- 事件执行顺序。
- 音符触发和释放。
- Loop 和轨道等待。
- 包络和 Portamento。
- 音色及波形解析。
- WAV 渲染输出。

这是与 GotaSequenceLib 独立的第二种实现思路，适合交叉验证。

### 10.4 3DSUSoundArchiveTool

仓库：

https://github.com/soneek/3DSUSoundArchiveTool

重点文件：

- `SEQ.h`
- `BNK.h`
- `INFOSection.h`
- `WAR.h`
- `WAV.h`
- `sar.h`

适合研究声音档案提取和文件间的引用关系。

项目较旧，不应默认其支持所有游戏和所有版本。

### 10.5 Caesar

仓库：

https://github.com/kr3nshaw/caesar

说明：从 Citrus Sound Archives 提取内容的工具。

可用于研究另一套 BCSAR 解析路径及历史上的 CSEQ 转换工作。

### 10.6 3sf

项目链接：

https://github.com/ogumaza/3sf

公开介绍：

https://www.hcs64.com/mboard/forum.php?showthread=65641

3sf 是面向 3DS 序列音乐的 PSF 家族方案。公开介绍提到从 BCSAR 提取音序，并结合 3DS DSP 固件进行播放。

对希望追求接近原始声音驱动行为的开发者有参考价值。

注意：本次未成功直接读取该 GitHub 仓库的源码页面，项目能力依据公开的 HCS64 作者说明；应在使用前自行检查仓库。

---

## 11. 历史逆向文档与社区资料

### 11.1 HCS64：cseq2mid

https://www.hcs64.com/mboard/forum.php?showthread=56433

这段讨论涉及：

- StreetPass 音序提取。
- soneek 的早期转换工具。
- kr3nshaw 的 cseq2mid 重写。
- 算术指令和子程序对 MIDI 转换造成的困难。
- BCSEQ 反编译器和 Opcode 文档。

讨论中提供的历史链接：

- BCSEQ 反编译器： https://pastebin.com/B9zGwBWb
- CSEQ 文件格式： https://pastebin.com/Q7SSJWNq
- CSEQ 指令文档： https://pastebin.com/BcWVm9kB

**可用性说明：**本次检索能确认这些链接确实出现在 HCS64 讨论中，但未成功获取 Pastebin 正文。不要将其内容视为已经核实。

### 11.2 HCS64：3DS Music

https://hcs64.com/mboard/forum.php?showthread=37864

包含大量关于 3DS 声音档案、提取工具、转换问题和游戏兼容性的历史讨论。

适合查找特定游戏的已知问题，不适合直接当作正式文件格式规范。

### 11.3 VGMDocs

https://loveemu.github.io/vgmdocs/Conversion_Tools_for_Video_Game_Music.html

用于确认 NW4C 文件家族的名称和工具生态。

这是一份工具索引，不是 BCSEQ Opcode 规范。

### 11.4 实际改造工作流

https://github-wiki-see.page/m/Kewlan/OoT3D-Custom-Sequences/wiki/Contributing

介绍使用 SequenceConvert 和文本序列修改 3DS 游戏音序的实践。

可用于研究如何将修改后的音序重新导入游戏，但它不是完整的 BCSEQ 技术规范。

---

## 12. 跨平台参考：只能比较，不能直接照搬

### BFSEQ 格式文档

https://nintendo-formats.com/libs/nw/bfseq.html

该文档详细解释了相关 NintendoWare 序列中的：

- 音符和等待。
- ProgramChange。
- Track Open / Jump。
- Tick / Tempo。
- Variable-Length Integer。
- 扩展变量运算。
- LABL 标签结构。

其目标格式是 BFSEQ，不是 3DS BCSEQ。

**使用原则：**

- 可以用来寻找相似的编码方式。
- 可以用来交叉检查同名指令。
- 不可以未经验证就将其全部参数类型、默认值和 Opcode 认定为 BCSEQ 的正式规范。
- 不能把 Switch 的小端 BFSEQ 行为套到 3DS 大端 BCSEQ。

---

## 13. 推荐的实现顺序

### 第一阶段：二进制容器解析

实现：

1. CSEQ 文件头。
2. BOM 和版本解析。
3. 块引用解析。
4. DATA 提取。
5. LABL 提取。
6. 偏移和边界校验。

输出结构化 JSON 或 AST，暂时不播放声音。

### 第二阶段：指令反汇编

实现：

1. 基础 Note / Wait / ProgramChange。
2. Jump / Call / Return / Fin。
3. OpenTrack / AllocateTrack。
4. `0xA0–0xA5` 参数包装。
5. `0xF0` 扩展指令。
6. 所有已确认控制 Opcode。
7. 未知 Opcode 的严格报错和原始字节记录。

反汇编输出至少应保留：

```text
track_id
instruction_offset
raw_bytes
opcode
decoded_parameters
target_offset
source_label
```

未知指令不能直接跳过，因为它可能具有未知长度，从而破坏后续指令边界。

### 第三阶段：音序虚拟机

为每条轨道维护独立状态：

```text
TrackState
  program
  bank
  volume
  pan
  transpose
  pitch_bend
  bend_range
  note_wait
  tie
  portamento
  ADSR overrides
  modulation state
  variables / condition state
  call stack
  loop stack
  wait_ticks
  program counter
```

具体字段作用域应由源码和样本确定，不能把上述建议模型当作已验证的官方结构。

实现时应加入执行预算，防止恶意或损坏文件中的无限循环、无限递归及零时间事件循环。

### 第四阶段：Bank 与采样

实现：

1. BCBNK 乐器查找。
2. Key Region 和 Velocity Region。
3. BCWAR 波形引用。
4. BCWAV 解码。
5. 采样 Loop。
6. Original Key、Pitch、Volume 和 Pan。
7. Voice 分配及释放。

### 第五阶段：播放和混音

实现：

1. 按 Tick 调度事件。
2. 根据 Tempo 将 Tick 转换为时间。
3. 创建和管理 Voice。
4. 采样重采样。
5. 包络和 LFO 更新。
6. 轨道与 Voice 增益计算。
7. Pan、Filter、Effect Send。
8. 输出 PCM / WAV。

音序解释器和混音器应是分离的模块。

---

## 14. 测试与验证要求

建议至少建立以下测试：

| 测试 | 验证内容 |
|---|---|
| Header round-trip | 文件头和块引用读写 |
| DATA/LABL round-trip | 音序和标签保留 |
| VLQ tests | 可变长度整数边界 |
| Jump / Call / Return | 控制流目标正确 |
| OpenTrack | 多轨入口和时间调度 |
| Nested parameter modifiers | Random、Variable、If、Time |
| Extended variables | 算术、比较和条件执行 |
| NoteWait / Tie | 音符持续与轨道推进 |
| LoopStart / LoopEnd | 有限和无限循环 |
| Tempo change | Tick 到时间转换 |
| Bank resolution | 正确选择乐器和波形 |
| Voice release | 包络结束和声部回收 |
| Malformed inputs | 越界、错误引用、非法 Opcode |
| Golden render | 与已有播放器输出比较 |

应优先使用从自己合法拥有的游戏或设备中提取的真实 BCSAR/BCSEQ 样本，不要只依赖人工构造的字节流。

可以参考 DualRip 的测试设计，但不能仅凭其存在测试就认定实现与原始硬件完全一致。

---

## 15. 已知不确定性与禁止猜测的地方

以下事项必须单独查证：

1. 每个 Opcode 在不同 NW4C 版本中的可用性。
2. CtrCafe 共享映射中的 Wii U 专有行为。
3. 所有指令的准确参数类型和取值范围。
4. 默认 Tempo 和 Timebase 的版本差异。
5. `ProgramChange` 与 Bank Select 的具体编码关系。
6. 变量索引作用域及其初始化方式。
7. 比较指令对条件状态的具体影响。
8. Random 参数的上下界和随机数算法。
9. Call Stack / Loop Stack 的深度限制。
10. NoteWait、Tie、Portamento 的原始驱动行为。
11. ADSR 值到实际时间常数的映射。
12. LFO 波形、周期、相位和更新频率。
13. DSP 与 CPU 对音量、包络、滤波的分工。
14. Voice 抢占优先级和最大复音数的实际限制。
15. 混响、Delay、Aux Send 的具体算法。
16. BCSEQ 在 BCSAR 中的资源绑定和运行时重定向。

遇到没有证据的功能，应该标记 `unknown` 或 `unimplemented`，不能由 LLM 自行补出看似合理的数值。

---

## 16. 给实现 LLM 的工作指令

请按照以下约束实现 Nintendo 3DS BCSEQ：

> 你正在实现 Nintendo 3DS NintendoWare for CTR 的 BCSEQ/CSEQ 解析器和音序解释器。
>
> 首先阅读本文件列出的公开资料及其对应源码，尤其是 Citric Composer 的 SEQ/Common 结构文档、SequenceConvert 的 BXSEQ.cs、GotaSequenceLib 的 CtrCafe.cs、SequenceCommand.cs、SequenceFile.cs，以及 DualRip 的 CTR 解析和播放实现。
>
> 只实现能够从 BCSEQ 相关文档、源码或真实测试文件得到证据的功能。
>
> 不要将 Nintendo DS SSEQ、Wii BRSEQ、Wii U BFSEQ 或 Switch BFSEQ 的指令行为无条件视为 BCSEQ 规范。
>
> 必须将二进制解析、指令反汇编、音序执行、Bank 解析、采样解码和混音器分开实现。
>
> 为每个 Opcode 建立明确的参数 Schema、证据来源、兼容性状态和单元测试。
>
> 对未知指令不得猜测长度或静默跳过。对越界偏移、非法引用、损坏的 VLQ、递归和无限循环进行防护。
>
> 保留原始字节和原始偏移，以支持调试、重新编码和无损 round-trip。
>
> 如果实现 MIDI 导出，必须明确说明 MIDI 无法完整表达 BCSEQ 的变量、随机控制流、动态循环、音源配置及部分混音行为。
>
> 如果实现音频渲染，必须使用实际 BCBNK/BCWAR/BCWAV，而不是将 ProgramChange 默认映射到 General MIDI。
>
> 最终提供 Opcode 覆盖率表、未实现行为清单、测试样本清单和与参考实现的差异报告。

---

## 17. 最终链接汇总

### 格式文档

- https://gota7.github.io/Citric-Composer/specs/seq.html
- https://gota7.github.io/Citric-Composer/specs/common.html
- https://gota7.github.io/Citric-Composer/specs/bnk.html
- https://gota7.github.io/Citric-Composer/specs/war.html
- https://gota7.github.io/Citric-Composer/specs/wav.html
- https://www.3dbrew.org/wiki/BCSAR
- https://www.3dbrew.org/wiki/BCWAV
- https://www.3dbrew.org/wiki/DSP_Memory_Region
- https://nintendo-formats.com/libs/nw/bfseq.html

### 解析与播放源码

- https://github.com/Gota7/GotaSequenceLib
- https://github.com/Gota7/GotaSequenceLib/blob/master/CtrCafe.cs
- https://github.com/Gota7/GotaSequenceLib/blob/master/SequenceCommands.cs
- https://github.com/Gota7/GotaSequenceLib/blob/master/SequenceCommand.cs
- https://github.com/Gota7/GotaSequenceLib/blob/master/SequenceFile.cs
- https://github.com/Gota7/GotaSequenceLib/blob/master/VariableLength.cs
- https://github.com/Gota7/GotaSequenceLib/tree/master/Playback
- https://github.com/Gota7/GotaSoundIO
- https://github.com/Gota7/SequenceConvert
- https://github.com/Gota7/SequenceConvert/blob/master/BXSEQ.cs
- https://github.com/Gota7/Citric-Composer
- https://github.com/TetraSsky/DualRip
- https://github.com/soneek/3DSUSoundArchiveTool
- https://github.com/kr3nshaw/caesar
- https://github.com/ogumaza/3sf

### 社区和历史资料

- https://www.hcs64.com/mboard/forum.php?showthread=56433
- https://hcs64.com/mboard/forum.php?showthread=37864
- https://www.hcs64.com/mboard/forum.php?showthread=65641
- https://pastebin.com/B9zGwBWb
- https://pastebin.com/Q7SSJWNq
- https://pastebin.com/BcWVm9kB
- https://loveemu.github.io/vgmdocs/Conversion_Tools_for_Video_Game_Music.html
- https://github-wiki-see.page/m/Kewlan/OoT3D-Custom-Sequences/wiki/Contributing

---

## 18. 资料局限与版权

本文是公开资料索引和实现说明，不是 Nintendo 官方发布的 BCSEQ 完整规范。

部分链接是历史社区资料，可能已经失效；部分开源项目可能存在未实现指令或兼容性问题。

使用源代码时应遵守各项目许可证。格式事实、指令名称和数据结构可以作为独立实现的研究依据，但直接复制 GPL 项目代码时必须考虑其许可证要求。

本文不附带任何商业游戏的声音档案、固件或受版权保护的采样资源。

