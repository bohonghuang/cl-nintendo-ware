# cl-nintendo-ware

Common Lisp NintendoWare C/F 音频文件读取库，覆盖 3DS、Wii U、Switch 共用的现代容器家族。只解析文件和事件语法；不执行音序，不解码音频，不实现播放。

所有二进制字段由 binstruct 声明并读取。文件、区块和引用直接返回声明生成的结构，不建立第二套结果模型或资源关联视图。Wii 的 R 系列和 NDS 的 Nitro 文件头不在本库范围内。

## 加载与测试

使用 SBCL、ASDF 和 Quicklisp。依赖 `alexandria`、`binstruct`、`parsonic`、`flexi-streams`。

```lisp
(ql:register-local-projects)
(ql:quickload :cl-nintendo-ware)
```

```bash
sbcl --dynamic-space-size 4096 --non-interactive --eval '(ql:quickload :cl-nintendo-ware :silent t)' \
  --eval '(asdf:test-system :cl-nintendo-ware)'
```

包名 `cl-nintendo-ware`，唯一昵称 `nintendo-ware`。

## 读取文件

`read-file` 仿照 cl-nitro，是按文件类型符号和输入类型分派的 generic function。公开 API 只有 `read-file`、下表八个文件符号，以及文件级提取工具 `xseq-events`／`xwar-waves`／`xsar-files` 和文件条目访问器 `xsar-file-name`／`xsar-file-data`；全部在 `package.lisp` 的 `defpackage` 中声明。section、字段访问器、事件类型、构造器和声明宏保持内部，测试一律使用 `::`，模块和宏不得动态导出它们。类型参数例如 `'nintendo-ware:xseq`，不接受 `:auto`、关键字或 C/F 格式名称。输入支持 pathname、文件名字符串、二进制流和 octet vector；pathname 打开为流，向量包装为内存输入流，各格式的流方法调用对应的内部 `read-x...` reader。

```lisp
(let* ((file (nintendo-ware:read-file 'nintendo-ware:xseq #P"/path/to/music.bcseq"))
       (events (nintendo-ware:xseq-events file)))
  (loop for event across events
        when (typep event 'nintendo-ware::xseq-event-note)
          collect (list (nintendo-ware::xseq-event-note-key event)
                        (nintendo-ware::xseq-event-note-duration event))))
```

每个被解析的完整文件都读取自己的 header，通过 magic 校验格式、通过 BOM 选择容器字节序。生成的完整文件 reader 不需要 `limit` 或端序参数。解析直接使用 binstruct 的流后端，不再将整个流复制到字节向量；输入流需要支持二进制读取和 `file-position` 定位。解析失败通过 `read-file` 报告为内部条件 `nintendo-ware::invalid-file`。

| 模块 | 结构 | 文件 magic |
|---|---|---|
| `sound/xseq.lisp` | `xseq` | CSEQ / FSEQ |
| `sound/xwav.lisp` | `xwav` | CWAV / FWAV |
| `sound/xwar.lisp` | `xwar` | CWAR / FWAR |
| `sound/xbnk.lisp` | `xbnk` | CBNK / FBNK |
| `sound/xwsd.lisp` | `xwsd` | CWSD / FWSD |
| `sound/xstm.lisp` | `xstm` | CSTM / FSTM |
| `sound/xsar.lisp` | `xsar` | CSAR / FSAR |
| `sound/xgrp.lisp` | `xgrp` | CGRP / FGRP |

模块和所属类型、函数、宏统一使用 `x` 加 magic 后三位的前缀；`x` 同时涵盖 C/F 两种容器。例如事件声明宏为 `define-xseq-event`，音符类型为 `xseq-event-note`。这是直接重命名，旧名称不再提供兼容别名。

BNK、WSD、SAR 的可选参数各有记录专属位域 set，开关字段使用 binstruct 原生 `(boolean bit)`，名称以 `-p` 结尾。语义字段按位号顺序直接读取，缺席为 `NIL`，不经通用整数数组二次解码。32 位数值位域在定义侧指定 `(:alignment 4)`，由 binstruct 原生处理整数分组和端序；`defbinstruct/me` 直接透传该选项，不重排字段。位号、资料来源及保留位规则见 [ENDIAN.md](ENDIAN.md#optional-parameter-flag-sets)。

`xwar-waves` 仿照 Nitro 的 `swar-waves`，直接返回按 wave index 排列的 WAV 结构向量；保留空引用为 `NIL`，不压缩索引，也不复制或解码编码音频。调用方不需要遍历 INFO section 和 reference entry。

共用解析布局不等于保证所有游戏、版本和编码组合兼容。原始 ID、引用、可选字段、DATA 及填充保留；空引用为 `NIL`。外部档案路径只读取为字符串，绝不自动打开。

### 语义枚举与开关

同 cl-nitro，枚举由原生 `defbinenum` 声明，读取后返回 `nintendo-ware` 包中的符号，不返回磁盘整数，也不提供整数兼容分支。调用方用 `eq`／`case`／`ecase`，不要再对枚举使用 `=` 或自行映射。

| 字段 | 符号（按磁盘值递增） |
|---|---|
| `xwav-info-codec`、`xstm-stream-info-encoding` | `pcm-8`、`pcm-16`、`dsp-adpcm`、`ima-adpcm` |
| `xbnk-note-flag-interpolation-type` | `polyphase`、`linear` |
| SEQ `mod-type`、`mod2-type`、`mod3-type`、`mod4-type` 的 `value` | `pitch`、`volume`、`pan` |
| SEQ `mod-curve`、`mod2-curve`、`mod3-curve`、`mod4-curve` 的 `value` | `sine`、`triangle`、`sawtooth`、`rectangular`、`random`、`none` |
| SEQ `mute` 的 `value` | `off`、`no-stop`、`release`、`stop` |
| `xsar-pan-mode-info-mode` | `dual`、`balance` |
| `xsar-pan-mode-info-curve` | `sqrt-negative-3`、`sqrt-0`、`sqrt-0-clamp`、`sincos-negative-3`、`sincos-0`、`sincos-0-clamp`、`linear-negative-6`、`linear-0`、`linear-0-clamp` |
| `xsar-sound-3d-info-attenuation-curve` | `logarithmic`、`linear` |
| `xsar-stream-sound-info-file-type` | `invalid`、`binary`、`adts`、`opus`；缺席仍为 `NIL` |

WAV 的 `loop` 改为 `xwav-info-loop-p`，STM 的 `loop-flag` 改为 `xstm-stream-info-loop-p`，track 的 `surround-mode` 改为 `xstm-track-surround-mode-p`，SAR 的 `leaf-flag`／`load-individually` 改为 `xsar-patricia-node-leaf-p`／`xsar-wave-archive-load-individually-p`，均返回 `T/NIL`。SEQ `monophonic`、`front-bypass`、`note-wait`、`tie`、`portamento-switch`、`damper` 的 `value` 也直接返回布尔值；调用方不要再用 `plusp`。

原始资源 ID、引用 tag、计数、连续参数和位掩码不是封闭枚举，仍保留数值。`biquad-type` 是可注册滤波 callback 的索引，不擅自把游戏自定义索引命名为固定滤波模式；见 [NW4R callback registry](https://github.com/NSMBW-Community/NSMBW-Decomp/blob/master/include/lib/nw4r/snd/snd_AxManager.h)。C/F 枚举依据 [Citric Composer](https://github.com/Gota7/Citric-Composer/tree/master/Citric%20Composer) 的 `SequenceDataLib` 和 `High Level` 声明；静音模式另参见 [SeqMute](https://github.com/NSMBW-Community/NSMBW-Decomp/blob/master/include/lib/nw4r/snd/snd_SeqTrack.h)。

### XSAR 文件提取

XSAR 仿照 cl-nitro 的 SDAT：读取元数据和各内嵌文件的原始字节，不解析子文件的 magic、BOM 或事件。`xsar-files` 返回按 File ID 排列的 simple-vector，每项为 `(name . data)` cons；`xsar-file-name` 和 `xsar-file-data` 分别访问 car／cdr。这三个入口在 `package.lisp` 的 `defpackage` 中导出。调用方决定哪些数据交给 `read-file`，未选择的未知或损坏子文件不会阻止 XSAR 提取。

名称是资源别名，不是附带扩展名的文件路径。按 sounds、banks、wave archives、groups 顺序填入，后出现的有名别名覆盖前面的名称，与 Nitro 一样；没有 STRG 或没有名字时为 `NIL`。内部文件的 data 为 octet vector，空文件保留零长度向量；空引用和外部文件为 `NIL`，不丢弃其 File ID。外部路径可通过内部访问器 `nintendo-ware::xsar-external-file-text` 检查，不自动打开。

```lisp
(let* ((archive (nintendo-ware:read-file 'nintendo-ware:xsar #P"/path/to/mset.bcsar"))
       (files (nintendo-ware:xsar-files archive))
       (file (aref files 0)))
  ;; 只选择这个 CSEQ；其余文件仍是原始字节。
  (values (nintendo-ware:xsar-file-name file)
          (nintendo-ware:read-file 'nintendo-ware:xseq
                                  (nintendo-ware:xsar-file-data file))))
```

移除旧的 `xsar-internal-file-content` 对象接口，不提供递归解析兼容层。WAR 中的 WAV 布局和 GRP 的内嵌 reader 不变；只有调用方显式读取相应文件时才进入这些 reader。


## 事件与端序

`xseq-events` 返回具体事件对象的向量，可直接以 `xseq-event-note`、`xseq-event-tempo` 等类型进行 CLOS 分派。字段直接表达音高、力度、时值、数值及内嵌 `sub-event`；不暴露 opcode、事件原始字节或二进制位置。开轨、跳转、调用的 `index` 和标签的 `xseq-label-entry-index` 均为该向量的零基索引。

`define-xseq-event` 仿照 Nitro 的 `define-sseq-event`，从同一份字段声明生成完整和 `/partial` 布局；random/variable 内嵌的子事件使用 `/partial`，省略最后一个参数，而不是最后一个字节。多字节事件标记不产生额外的消费对象，reader 直接返回具体事件类型。

事件标记参数 `event-bytes` 用 `ensure-list` 统一：单字节写 `(wait #x80)`，多字节写 `(mod2-phase (#xf0 #xa1))`，也支持任意更长的固定字节序列。每个标记字节生成一个独立的 `satisfies`/`eql` 声明；没有 `extended` 标志或专用扩展事件 union。`/partial` 由外层提供已消费的第一个标记字节，其余标记字节仍逐个校验，只省略最后一个参数。音符的首字节是音高，因此单独声明其范围布局。

事件选择使用 binstruct 的 `(or (事件类型) ...)` union，各类型的首字节声明校验操作码；不使用运行时 opcode 描述表或手写事件读取循环。`defbinio` 仅用于完整文件的最终代码生成，不提供事件级二进制读取 API。

容器 BOM 与事件字节序分别处理：CSEQ 事件固定大端；Wii U FSEQ 为大端；Switch FSEQ 为小端。文件声明选择事件流布局，消费端无需处理端序。所有平台共享事件声明，不施加平台 opcode 白名单。

CSTM SEEK 上下文固定小端；当前 FSTM SEEK 布局按 Citric 的参考实现使用大端上下文，独立于区块头 BOM。编码音频始终保留原始字节，不因容器换端序而交换音频 payload。

## 声明模式

`define-nintendo-ware-file`、`define-nintendo-ware-section` 按 `cl-nitro` 的声明方式，名称／选项后直接写字段，不带参数表；具体 file、section 及 section body 的 reader 均无参数。每个具体 file 只生成一个 reader：公共容器读取文件头的 BOM，再用 `ecase` 和 `inline` 选择 `body/be` 或 `body/le`，将已解析的 header 传给 body。只有 body、区块及记录保留共享 Lisp 类型的大小端布局，不生成完整文件的 `/le`、`/be` 入口。file／section 均生成直接字段访问器。现代容器仍按 sized reference 定位区块，而非假设区块连续排列。

```lisp
(define-nintendo-ware-section (sample-info (:magic "INFO"))
  (value 0 :type (unsigned-byte 32)))

(define-nintendo-ware-file (sample-file (:magic "CSMP"))
  (info nil :type (peek sample-info (block-start header #x1000))))
```

file body 直接接收容器已读取的 header；section body 通过原生位置引用取得所属文件头与版本。普通记录、表、字符串和引用按声明的字段及数量读取，不接收或传递区块结束位置。每个文件字段读取前恢复本文件的位置锚点，避免内嵌文件影响外层后续区块。GRP 的内嵌 reader 只按 magic 选择文件类型，由子文件自身容器读取 BOM，不预读 BOM 来选择完整文件的大小端 reader；XSAR 不走这条递归路径。高阶 parser（`inline` 等）仅用于 file／section 容器，不用于具体记录、引用、表或事件。

只有确实需要剩余长度的布局使用零宽类型 `nintendo-ware-section-tail-size`，保存在 `%size`：它返回“区块大小 −（当前位置 − 区块起点）”，不消费输入，并遵循区块头端序。需要绝对结束位置时，就地用 `%position + %size` 计算。目前仅 SEQ 的无计数事件流需要结束位置，SEEK 需要剩余长度来读取尾部 padding；不向其他布局注入尾部上下文。

```lisp
(defbinstruct/me sample-point
  (x 0 :type (signed-byte 16))
  (y 0 :type (signed-byte 16)))

(defbinstruct/me sample-pair
  (first (make-sample-point) :type sample-point)
  (second (make-sample-point) :type sample-point))
```

`defbinstruct/me` 的规则：

1. 默认定义为小端；`/le` 是延后展开的别名。
2. 在本库独立的 `*endian*` 特殊变量绑定为 `:big` 时，提前展开 `/be` 的 `defbinstruct`，用 `(:type 原类型)` 共享 Lisp 数据布局。
3. 通过 reader 类型展开方法，使嵌套结构和数组元素自动使用相应 `/le`、`/be`。不传递运行时端序参数，不复制 Lisp 结构类型。

也接受 binstruct 风格的可选参数列表；生产 schema 最多三个参数。递归类型需先声明端序分派，见 `xseq-event-union`。打包进一个整数的子字段若在两端字节位置不同，则显式声明共享 Lisp 类型的两种布局，不假装字段顺序相同。

相对引用使用 `reference-to` 和原生 `pointer`；前者只在编译期展开具体读取表达式，不引入接收 parser 参数的运行时 reader。保留 magic、opcode、引用 tag、BOM／布局分派、空引用处理及其他非大小相关检查；不检查文件／区块声明大小的一致性、目录跨度或区块重叠。XSAR 的 sized reference 长度用于读取原始文件 data，不用于校验其内部格式；WAR／GRP 的内嵌 reader 不增加长度约束包装。大小字段仍用于实际 payload 和 padding 的读取，不提供完整格式校验或受限输入沙箱。

**本库只保证 reader。** 不为 writer 增加端序钩子，不测试、不保证自动生成的 writer 正确性；保留正常 binstruct 声明与指针信息，方便将来实现。

## 验证范围与参考

测试使用 Common Lisp assertions 和独立 binstruct 输入夹具，检查实际字段、引用目标、可空引用、magic／opcode 识别、大小端、嵌套事件及版本分支，不断言生成源码或测试库的 writer。

新事件接口通过 [OoT3D-Custom-Sequences](https://github.com/Kewlan/OoT3D-Custom-Sequences) 的 63 个 BCSEQ 文件，共读取 401,232 个顶层事件并完成目标索引转换。此数量包含声明式事件流读取到的非静态可达事件，不等同于旧 reader 的静态遍历计数。另已用实际 `closynth:event-emit` 验证解析所得 note/tempo 对象的类型分派，未接入播放。Citric 的 `guts.bcseq` 有一个开轨目标落在扩展指令内部，索引化时拒绝，不擅自重定位。除下面的 BCSAR 样本外，其他格式与平台主要依赖合成夹具验证，不能据此宣称所有商业游戏兼容。

已通过公开 `read-file` 接口读取 [pmee 的 `mset.bcsar`](https://github.com/bohonghuang/pmee/blob/01f93480dea5e3e99a2e0d658381fd3a2052423d/mset.bcsar)（383,408 字节，CSAR／小端）。pathname、二进制流、octet vector 三种输入均通过；67 个字符串、50 个声音的名称与文件／播放器 ID、音量、序列 bank／起始偏移／优先级，以及显式解析后的 5 个 CWSD item／note 字段与 [DualRip](https://github.com/TetraSsky/DualRip) 独立解析结果交叉核对。测试先通过 `xsar-files` 提取 19 个文件的原始字节，再由调用方显式解析全部文件：5 个 CSEQ（35,225 个顶层事件）、2 个 CWSD、5 个 CBNK、7 个 CWAR；读取 CWAR 时解析其中 34 个 CWAV／34 个声道，保留 273,362 字节编码音频，不进行解码或播放。

样本 SHA-256：`e96097ab77e70837cee31acd2c3c132da56a262add4aa8e1fa27d623ecdf7323`。原始文件已纳入 `test/data/mset.bcsar`，由默认 `asdf:test-system` 执行 `test/pmee.lisp` 中的真实归档回归；测试不联网，也不需要外部 checkout。断言 cons 名称／原始数据长度和声音元数据，随后显式解析并验证完整序列事件数量、CWSD 效果参数、project-info，以及全部 CWAV 的 codec／采样率／样本数和编码数据总量。合成回归覆盖不解析损坏／未知子文件、可选名称、空数据／空引用／外部文件，以及跨端序显式读取；原有 WSD 参数和 SAR project-info tag 回归仍保留。

```lisp
(nintendo-ware:read-file 'nintendo-ware:xsar
                         (asdf:system-relative-pathname :cl-nintendo-ware #P"test/data/mset.bcsar"))
```

- [ENDIAN.md](ENDIAN.md)：各平台、容器及事件流的端序证据。
- [BCSEQ.md](BCSEQ.md)：3DS 音序、引用和格式资料。
- [Citric Common Structures](https://gota7.github.io/Citric-Composer/specs/common.html)、[Sequences](https://gota7.github.io/Citric-Composer/specs/seq.html)、[Banks](https://gota7.github.io/Citric-Composer/specs/bnk.html)、[Wave Archives](https://gota7.github.io/Citric-Composer/specs/war.html)。
- [Citric Composer 源码](https://github.com/Gota7/Citric-Composer)、[GotaSequenceLib](https://github.com/Gota7/GotaSequenceLib)。
