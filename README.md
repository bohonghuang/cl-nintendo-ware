# cl-nintendo-ware

Common Lisp NintendoWare C/F 音频文件读取库，覆盖 3DS、Wii U、Switch 共用的现代容器家族。只解析文件和事件语法；不执行音序，不解码音频，不实现播放。

所有二进制字段由 binstruct 声明并读取。文件、区块和引用直接返回声明生成的结构，不建立第二套结果模型或资源关联视图。Wii 的 R 系列和 NDS 的 Nitro 文件头不在本库范围内。

## 加载与测试

使用 SBCL、ASDF 和 Quicklisp。依赖 `alexandria`、`binstruct`、`parsonic`、`flexi-streams`。

```lisp
(ql:register-local-projects)
(asdf:load-system :cl-nintendo-ware)
```

```bash
sbcl --dynamic-space-size 4096 --non-interactive --eval '(asdf:load-system :cl-nintendo-ware)' \
  --eval '(asdf:test-system :cl-nintendo-ware)'
```

ME 保留默认 LE 布局、显式 `/le` 别名和共享语义类型的 BE 布局；naive inline 收集器为 `/le` 别名转发 parser 参数。LE 的 `:include` 保持不变；BE 的祖先名称在祖先所属包中通过 `find-symbol` 查找对应 `/be`，不存在即报错，其余参数仍由 binstruct 原生展开。reader/writer hook 对称选择 `/le` 或 `/be`；binstruct 的 include 使用 default expansion，不经过该 hook。STM SEEK 的 magic 默认值为新建的四字符 base-string，避免空字符串索引警告及共享常量造成的分支折叠。

包名 `cl-nintendo-ware`，唯一昵称 `nintendo-ware`。

## 读取文件

`read-file` 仿照 cl-nitro，是按文件类型符号和输入类型分派的 generic function。公开 API 仅覆盖第一层：`read-file`、下表八个文件符号，以及从文件直接提取本质数据的函数。返回的事件、声道、乐器、item、流元数据和依赖记录通过内部 `nintendo-ware::` API 继续访问，不逐项导出其类型或字段；section、引用、body、构造器和声明宏保持内部。全部导出在 `package.lisp` 的 `defpackage` 中声明，模块和宏不得动态导出。类型参数例如 `'nintendo-ware:xseq`，不接受 `:auto`、关键字或 C/F 格式名称。输入支持 pathname、文件名字符串、二进制流和 octet vector；pathname 打开为流，向量包装为内存输入流，各格式的流方法调用对应的内部 `read-x...` reader。

```lisp
(let* ((file (nintendo-ware:read-file 'nintendo-ware:xseq #P"/path/to/music.bcseq"))
       (events (nintendo-ware:xseq-events file)))
  (loop for event across events
        when (typep event 'nintendo-ware::xseq-event-note)
          collect (list (nintendo-ware::xseq-event-note-key event)
                        (nintendo-ware::xseq-event-note-duration event))))
```

每个被解析的完整文件都读取自己的 header，通过 magic 校验格式、通过 BOM 选择容器字节序。生成的完整文件 reader 不需要 `limit` 或端序参数。解析直接使用 binstruct 的流后端，不再将整个流复制到字节向量；输入流需要支持二进制读取和 `file-position` 定位。`read-file` 不捕获或包装解析错误，直接暴露 binstruct 原生 condition（例如 `binstruct::deserialize-error`），保留底层提供的 input、position 和 info；流自身的错误也原样透出。语义校验失败同样直接使用 `binstruct::deserialize-error`；无法取得流或位置的校验将这两个字段设为 `NIL`。

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

| 文件 | 公开的文件级提取 API | 返回内容 |
|---|---|---|
| SEQ | `xseq-events` | 语义事件数组，流程目标已转换为事件索引 |
| WAV | `xwav-channels`；`xwav-codec`、`xwav-sample-rate`、`xwav-loop-p`、`xwav-loop-start`、`xwav-loop-end` | 声道数组及波形属性；loop-end 为排他结束样本位置，也是样本数 |
| WAR | `xwar-waves` | 按 wave index 排列的 WAV／NIL 向量 |
| BNK | `xbnk-instruments`、`xbnk-waves` | 乐器定义数组及引用的 wave ID 数组 |
| WSD | `xwsd-items`、`xwsd-waves` | item 数组及引用的 wave ID 数组 |
| STM | `xstm-stream`、`xstm-tracks`、`xstm-channels`、`xstm-seek-table` | 流元数据（含样本与 region 数据）、track／channel 数组及 SEEK 记录 |
| SAR | `xsar-files`；`xsar-file-name`、`xsar-file-data` | 按 file ID 排列的 `(name . raw-data)` 条目及其访问器 |
| GRP | `xgrp-entries`、`xgrp-dependencies` | 保留 file ID 的成员条目数组及资源依赖数组；缺少 INFX 时依赖为 NIL |

新增提取函数直接返回已解析的字段，不复制数组、不解码音频、不再次读取二进制。数组保留原有索引及 NIL 项；下一层字段仍使用内部 API，例如 `(nintendo-ware::xwav-channel-data (aref (nintendo-ware:xwav-channels wave) 0))`。

模块和所属类型、函数、宏统一使用 `x` 加 magic 后三位的前缀；`x` 同时涵盖 C/F 两种容器。例如事件声明宏为 `define-xseq-event`，音符类型为 `xseq-event-note`。这是直接重命名，旧名称不再提供兼容别名。

`common.lisp` 保留共用的 magic/version 查询和 major-version 布局。`reference.lisp` 集中通用引用布局、辅助类型及引用声明宏，在 `binary.lisp` 之后、`file.lisp` 之前加载。`read-file` 及输入类型分派、文件头和文件容器位于 `file.lisp`，区块布局位于 `section.lisp`。`sound/sound.lisp` 在所有 `sound/x___.lisp` 之前加载，共用 codec、channel-index 数组、resource ID 和 wave ID 布局统一使用 `nintendo-ware-sound-` 前缀。NintendoWare 专有类型使用库或模块前缀，通用 VLQ 原语保持原名；记录位域类型统一命名为 `*-flags`。SAR 专用的 File ID 数组、资源 ID 数组、priority 数值字段位于 `sound/xsar.lisp`，使用 `xsar-sound-group-files`、`xsar-resource-ids`、`xsar-packed-priority`；WSD 专用 pan/filter 数值字段位于 `sound/xwsd.lisp`，使用 `xwsd-packed-pan`、`xwsd-packed-filter`，访问器同样带模块前缀。

仅含计数、定位锚点和元素数组的布局使用 `(:constructor progn)`、`(:conc-name nil)` 和显式的 `(:type (simple-array ... (*)))`，直接返回数组，不再生成 `*-table` 结构或要求调用 `*-table-entries`／`*-table-count`。计数只用于解析，调用方使用 `length`。普通记录的数组访问器如 `xwsd-track-events`、`xwsd-item-tracks`、`xwsd-item-notes` 保持不变；section 字段可直接通过自动生成的访问器访问，如 `xwsd-info-items`、`xbnk-info-instruments`、`xstm-info-tracks`／`xstm-info-channels`、`xsar-strg-strings` 和 `xsar-info-sounds`。共用数组布局为 `nintendo-ware-sound-channel-indices`、`nintendo-ware-sound-wave-ids` 和 `xsar-resource-ids`。`xstm-seek-row` 同样直接返回 SEEK entry 数组。空引用保持 `NIL`，非空引用的零计数返回空数组，数组内空引用不压缩索引；不提供旧包装的兼容别名。具有 upper bounds、range 或 Patricia root 等独立语义字段的记录以及原生 section 容器保持结构。

```lisp
(let* ((items (nintendo-ware::xwsd-info-items (nintendo-ware::xwsd-info wsd)))
       (item (aref items 0))
       (track (aref (nintendo-ware::xwsd-item-tracks item) 0)))
  (loop for event across (nintendo-ware::xwsd-track-events track)
        when event collect (nintendo-ware::xwsd-event-note-index event)))
```

这次迁移覆盖 21 个纯数组布局；回归使用直接数组访问，并检查 C/F、双端序下 WSD 的空引用、空数组和中间含有效事件的稀疏数组。默认测试继续完整解析 MSET、TigerSound 和 menu 真实归档。

简单 `satisfies` 谓词优先使用 Alexandria 的 `curry`／`rcurry`，无额外参数时直接使用函数引用；参数位于中间、需要字段提取／计算或包含多个条件时保留 lambda。

BNK、WSD、SAR 的可选参数各有记录专属位域 set，开关字段使用 binstruct 原生 `(boolean bit)`，名称以 `-p` 结尾。语义字段按位号顺序直接读取，缺席为 `NIL`，不经通用整数数组二次解码。32 位数值位域在定义侧指定 `(:alignment 4)`，由 binstruct 原生处理整数分组和端序；`defbinstruct/me` 直接透传该选项，不重排字段。位号、资料来源及保留位规则见 [ENDIAN.md](ENDIAN.md#optional-parameter-flag-sets)。

`xwar-waves` 仿照 Nitro 的 `swar-waves`，直接返回按 wave index 排列的 WAV 结构向量；保留空引用为 `NIL`，不压缩索引，也不复制或解码编码音频。调用方不需要遍历 INFO section 和 reference entry。

共用解析布局不等于保证所有游戏、版本和编码组合兼容。原始 ID、引用及可选字段保留；空引用为 `NIL`。外部档案路径只读取为字符串，绝不自动打开。

资源 ID 按原生 32 位数值位域解析为内部 `nintendo-ware-sound-resource-id`：`nintendo-ware-sound-resource-id-index` 是低 24 位表索引，`nintendo-ware-sound-resource-id-type` 是高 8 位类型 tag；`nintendo-ware-sound-resource-id-value` 可无损取得原值，包括未知 tag 和 `#xffffffff`。WAV/BNK/WSD 的 `nintendo-ware-sound-wave-id-archive-id`、SAR 的资源引用与资源 ID 数组、GRP dependency 均使用此布局；`xsar-sequence-info-banks`、`xsar-bank-wave-archives` 和 `xsar-wave-sound-group-wave-archives` 直接返回资源 ID 数组，`xsar-sound-group-files` 直接返回普通 File ID 的 `(unsigned-byte 32)` 数组。消费端不再自行提取位。类型 tag 保留为整数，不擅自拒绝未知资源种类。

### WAV 原生采样数据

`xwav-channel-data` 由声明中的 `ecase` 按 codec 直接读取最终专用数组，不先读取 octet vector 再做符号转换、拼接 PCM16 或拆 nibble。移除旧 `xwav-channel-encoded-data`，不提供兼容副本。`count` 为 `xwav-info-loop-end`，也是非循环波形的样本数。

IMA 样本直接声明为 `(simple-array (unsigned-byte 4) (sample-count))`，使用 binstruct 修复后的原生数组解析，不再单独定义 `xwav-ima-samples` 包装布局。

| `xwav-info-codec` | `xwav-channel-data` 元素类型 | 长度与顺序 |
|---|---|---|
| `pcm-8` | `(signed-byte 8)` | `count`；可直接传入 `s8-pcm-source` |
| `pcm-16` | `(signed-byte 16)` | `count`；reader 按 WAV 自身 BOM 读出数值，可直接传入 `s16-pcm-source` |
| `dsp-adpcm` | `(unsigned-byte 8)` | `8 * ceiling(count / 14)`；保留原生 DSP 帧，可直接交给后续 DSP-ADPCM source |
| `ima-adpcm` | `(unsigned-byte 4)` | `count`；每字节低 nibble 在前，与 BOM 无关；奇数样本数不包含最后未使用的高 nibble，可直接传入 `ima-adpcm-source` |

DSP 帧为一个 header 字节加七个采样字节：header 高 nibble 是 predictor／系数对索引，低 nibble 是 scale，随后 14 个残差按每字节高 nibble 在前排列。这里不把 DSP 解码成 PCM，也不分配另一份 nibble 数组；future source 在渲染时直接消费帧。系数及初始／循环 history 保留在 `xwav-channel-codec-info` 的 `xwav-dsp-adpcm-info` 中。IMA 的初始／循环 predictor 和 step-index 则在 `xwav-ima-adpcm-info` 中，data 不重复嵌入状态头。

每个通道只读取自己的最终数组；`xwav-data` 仅校验 DATA 区块头并建立 `$xwav-data-start`，不复制整块原始音频或对齐填充。INFO 中的原生延迟指针在 DATA 锚点就绪时完成样本读取，完整 reader 返回前结果已齐备。调用方不要再 `map` 有符号 PCM、按字节拼 PCM16、拆 IMA nibble，或预先渲染整段 ADPCM。构造 source 时直接共享 data，音频解码由消费端在渲染时完成。本库不添加音频解码器或播放器。

合成回归覆盖 C/F × LE/BE、有符号极值、PCM16 非对称字节、奇数／零样本数、DSP 跨帧及不同 BOM 的内嵌 WAV。额外 smoke 使用现有 Closynth 的 `s8-pcm-source`、`s16-pcm-source`、`ima-adpcm-source`：共享同一 data 对象，只渲染短窗口，并通过跟踪输入流确认每个通道 payload 字节只读一次。没有修改 Closynth，也没有宣称当前存在 DSP source。

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

资源 ID 的类型 tag、引用 tag、计数、连续参数和位掩码不是封闭枚举，仍保留数值；完整资源 ID 使用上面的原生位域结构。`biquad-type` 是可注册滤波 callback 的索引，不擅自把游戏自定义索引命名为固定滤波模式；见 [NW4R callback registry](https://github.com/NSMBW-Community/NSMBW-Decomp/blob/master/include/lib/nw4r/snd/snd_AxManager.h)。C/F 枚举依据 [Citric Composer](https://github.com/Gota7/Citric-Composer/tree/master/Citric%20Composer) 的 `SequenceDataLib` 和 `High Level` 声明；静音模式另参见 [SeqMute](https://github.com/NSMBW-Community/NSMBW-Decomp/blob/master/include/lib/nw4r/snd/snd_SeqTrack.h)。

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

XSAR 和 GRP 均不自动解析子文件，不检查其 magic、BOM 或事件；WAR 的 WAV reader 不变。旧的 `xsar-internal-file-content`、`xgrp-entry-content` 对象接口不保留兼容层。

GRP 条目通过 `nintendo-ware::xgrp-entry-file-id` 保留归档中的原始文件索引，不能把条目在组表中的位置当作文件 ID。`nintendo-ware::xgrp-entry-data` 返回原始 octet vector；空引用返回 `NIL`，零长度数据仍为专用空 octet vector。按文件 ID 选择条目后，调用方显式指定类型解析：

```lisp
(let* ((group (nintendo-ware:read-file 'nintendo-ware:xgrp #P"/path/to/group.bcgrp"))
       (entry (find 7 (nintendo-ware::xgrp-info-entries (nintendo-ware::xgrp-info group))
                    :key #'nintendo-ware::xgrp-entry-file-id)))
  (when (and entry (nintendo-ware::xgrp-entry-data entry))
    (nintendo-ware:read-file 'nintendo-ware:xseq (nintendo-ware::xgrp-entry-data entry))))
```


## 事件与端序

`xseq-events` 返回具体事件对象的向量，可直接以 `xseq-event-note`、`xseq-event-tempo` 等类型进行 CLOS 分派。字段直接表达音高、力度、时值、数值及内嵌 `sub-event`；不暴露 opcode、事件原始字节或二进制位置。开轨、跳转、调用的 `index` 是该向量的零基索引。DATA 与 LABL 互不引用；LABL 的 `xseq-label-entry-offset` 直接保留原始有符号 offset（包括 `-1`），不跟随目标、不转换为事件索引，也不校验事件边界。

`define-xseq-event` 仿照 Nitro 的 `define-sseq-event`，从同一份字段声明生成完整和 `/partial` 布局；random/variable 内嵌的子事件使用 `/partial`，省略最后一个参数，而不是最后一个字节。多字节事件标记不产生额外的消费对象，reader 直接返回具体事件类型。

内部 `xseq-event-variable-value` 与 `(setf xseq-event-variable-value)` 由 `define-xseq-event` 生成，仅处理最后一个 slot 的 `:type`。与 cl-nitro 一致，声明宏以 `ignore-errors` 获取原生 bounds：取不到 bounds 时不生成方法；两值相等时，以 `pushnew :test #'equal` 收集类型、声明 reader／writer 的 `ftype`，并生成通过原生编解码读写低十六位的方法；两值不相等时，生成直接读写字段整数值的方法，VLQ 不经过原始字节重解码。note 也由同一声明宏生成，duration 与 wait、program-change 的 VLQ 参数使用相同路径；音符布局和 `/partial` 消费规则不变。所有事件声明后，`defbinio-xseq-event-variable-value-types` 为已收集的定长类型生成 `defbinalias`／`defbinio`，不保存 plist 或方法队列，不事后筛选，也不访问 binstruct emitter 内部实现。定长方法不按类型特判、不限制字段位宽；宽字段的两字节 setter 限制由原生 reader 报错。events 与 variable-value 类型注册表均使用 `defvar`。

事件标记参数 `event-bytes` 用 `ensure-list` 统一：单字节写 `(wait #x80)`，多字节写 `(mod2-phase (#xf0 #xa1))`，也支持任意更长的固定字节序列。每个标记字节生成一个独立的 `satisfies`/`eql` 声明；没有 `extended` 标志或专用扩展事件 union。`/partial` 由外层提供已消费的第一个标记字节，其余标记字节仍逐个校验，只省略最后一个参数。note 的首字节是音高，由同一宏生成 key 范围布局，不作为固定标记。

事件选择使用 binstruct 的 `(or (事件类型) ...)` union，各类型的首字节声明校验操作码；不使用运行时 opcode 描述表或手写事件读取循环。`defbinio` 用于完整文件的最终代码生成，以及上述内部 variable-value slot reader／writer；不提供事件流遍历 API。

容器 BOM 与事件字节序分别处理：CSEQ 事件固定大端；Wii U FSEQ 为大端；Switch FSEQ 为小端。文件声明选择事件流布局，消费端无需处理端序。所有平台共享事件声明，不施加平台 opcode 白名单。

CSTM SEEK 上下文固定小端；当前 FSTM SEEK 布局按 Citric 的参考实现使用大端上下文，独立于区块头 BOM。WAV PCM16 按自身 BOM 解析为有符号样本；DSP 帧字节和 IMA nibble 顺序遵循 codec，不随容器端序交换。STM 的样本仍为原始字节，由 `xstm-stream-info-sample-data` 保存；DATA 只建立样本区锚点。

## 声明模式

`define-nintendo-ware-file`、`define-nintendo-ware-section` 按 `cl-nitro` 的声明方式，名称／选项后直接写字段，不带参数表；具体 file、section 及其 body reader 均无参数。file 直接读取 magic、BOM、version 和 sized-reference 目录，保留语义 section 数组；BOM 选择明确的 LE／BE 数值和 section union 布局。目录 union 只接受声明的 tag，没有 unknown fallback。section 使用明确端序的 `inline` body，并仿照 `cl-nitro` 为未被 binstruct 排除的字段自动生成 `xxx-field` getter／`(setf xxx-field)`，以内联函数转发到原生 body 访问器；这些访问器保持包内部，不自动导出。容器保留原生起止锚点、padding 前的局部 `%end` 和声明式 remaining padding；目前不实现 size 回写，也不保证 writer 可用。区块按真实目录引用定位，不假设目录顺序与物理顺序一致或区块连续排列。

body 仅属于 `define-nintendo-ware-*` 的实现细节；外部代码必须将其视为不存在。库内调用方、测试与文档示例均禁止直接访问 body 槽、类型或访问器，必须使用自动生成的 section 字段访问器。

```lisp
(define-nintendo-ware-section (sample-info (:magic "INFO"))
  (value 0 :type (unsigned-byte 32)))

(define-nintendo-ware-file (sample-file (:magic "CSMP"))
  (info (make-sample-info) :type sample-info :tag #x1000))
```

不再构造或重读旧 header 对象。file-section accessor 保持单参数签名，返回 `sections` 中首个匹配语义类型的 section 或 `NIL`。每个目录引用返回后恢复所属文件的起点锚点，避免内嵌 WAV 覆盖外层上下文。BOM 使用固定 BE 枚举：FF FE 为 LE、FE FF 为 BE，未知值暴露原生 `type-error`。GRP／XSAR 只读取原始子文件数据；显式读取子文件时，由其自身容器读取 BOM。高阶 `inline` 用于容器和 typed reference 的共用包装，具体记录和事件不直接使用高阶 parser。

只有确实需要剩余长度的布局使用零宽类型 `nintendo-ware-section-tail-size`，保存在 `%size`：它通过当前 section 的起点锚点回读对应端序的 size 字段，计算剩余长度，不消费输入。需要绝对结束位置时，就地用 `%position + %size` 计算。目前只有 SEQ 的无计数事件流使用此布局；不向其他 body 注入 header 或尾长字段。

```lisp
(defbinstruct/me sample-point
  (x 0 :type (signed-byte 16))
  (y 0 :type (signed-byte 16)))

(defbinstruct/me sample-pair
  (first (make-sample-point) :type sample-point)
  (second (make-sample-point) :type sample-point))
```

`defbinstruct/me` 的规则：

1. 默认定义为小端；`defbinstruct/be` 在本库独立的 `*endian*` 绑定为 `:big` 时提前展开 `/be`，用 `(:type 原类型)` 共享 Lisp 数据布局。
2. reader 的 symbol-property 函数在字段展开时按编译期 `*endian*` 选择 `/le` 或 `/be`，将参数原样透传给 binstruct 的 `expand-reader-type-expr`；未绑定或为 `NIL` 时默认小端。`/le` 通过 symbol-property 展开到默认定义，不生成额外布局。默认类型不注册 writer plist function；显式 `/le` 的 writer 透传到默认原生 writer。
3. inline 参数处理和 reader／writer 展开归 binstruct；ME 宏不扫描 inline 参数，不手写 parser unit 或 emitter 调用。既有调用方和显式强制 LE alias 保持原样。

也接受 binstruct 风格的可选参数列表；生产 schema 最多三个参数。递归类型用无 body 的 `(defbinstruct/me name)` 提前注册展开函数，随后提供完整声明，见 `xseq-event-union`。打包为 32 位整数的数值子字段统一用 `(:alignment 4)`，由 binstruct 按位偏移和端序处理，不手写反序布局。

`defbinalias` 和 `defbinalias/me` 共用内部宏 `%defbinalias`：首个参数是要调用的宏符号，分别传入 `defbinstruct` 和 `defbinstruct/me`；类型推断、显式 `:type` 和单值布局声明只实现一次。

`defbinalias/me` 与 `defbinalias` 使用相同的类型推断和显式 `:type` 约定，通过 `defbinstruct/me` 创建 LE／BE 的 `(:constructor progn)`、`(:conc-name nil)` 单值布局。

引用通过 `define-nintendo-ware-reference` 声明 tag 与目标布局的对应关系，结果直接是目标值或 `NIL`，不再生成含 tag／offset 的 reference 对象。多个分支使用原生 `or` 分派；同一个 tag 在不同引用声明里可以对应不同目标类型。生成的 alias 使用 ME，以保证 BE 下的目标布局也正确分派：

```lisp
(define-nintendo-ware-reference my-reference ()
  (#x6000 (target-type-1))
  (#x6001 (target-type-2)))

;; 生成 my-reference-array；count 和每个元素的相对基址均在数组布局内部。
(define-nintendo-ware-reference-array my-reference-array ()
  (rcurry #'my-reference))
```

字段使用 `(my-reference %base)`。两个声明宏均接受显式 lambda-list；无参数时写 `()`。例如 `(define-nintendo-ware-reference xbnk-instrument-reference (wave-count) (#x5900 (xbnk-instrument wave-count)))` 生成 `(xbnk-instrument-reference %base wave-count)`。数组名称显式指定：`(define-nintendo-ware-reference-array instruments (wave-count) (rcurry #'xbnk-instrument-reference wave-count))`。`curry`／`rcurry` 只是宏展开标记，不创建闭包：`(curry #'reader a b)` 生成 `(reader a b base)`，`(rcurry #'reader a b)` 生成 `(reader base a b)`；标记必须为这两个符号之一，reader 必须使用 `#'`，即 `(function reader)`。数组元素类型仍由 `binstruct::lisp-type` 推导。引用 alias 连同隐式 base 最多三个参数，数组 lambda-list 不含该隐式 base。

`(:sized t)` 选择 12 字节引用，否则为 8 字节。二者使用同一个 `nintendo-ware-reference` 布局，由原生 `pointer` 定位、共用 `nintendo-ware-reference-target` 的 `inline` 包装；结果不含指针或供用户解引用的偏移。非空引用校验 tag 和 offset；`-1` 为空引用，保留其 tag 未定义的既有语义。Citrus 的非零基址使 pointer 可定位到 base−1，然后由 target 内的位置比较返回 `NIL`，不进入目标布局。框架不承诺零基址空引用。

sized target 如需长度，必须在开头通过 `(%size 0 :type nintendo-ware-reference-size)` 获取并保存，再读取其他字段或子引用。这个 ME alias 通过原生零宽 `pointer`，按引用的端序直接读取 `$nintendo-ware-reference-size` 指向的 u32 size 字段；嵌套 reference 会覆盖该全局锚点，不保证返回父布局后再次查询仍得到父 size。普通引用没有声明长度，目标按自身布局读取，不使用 size 查询。target 以局部 `%start`／`%end` 记录实际读取范围；sized target 末尾保留原生 `peek`／`map` 声明，读取时不改动 size，写入时可将实际长度回写到捕获的 size 字段位置。sized 分支以 `0` 初始化 size 占位值。临时 LE／BE smoke 已验证 tag 为 0、非零基址下的 3 字节目标 size 回填、零长度目标及普通引用不含 size 字段；这不是完整 writer 验证。回写不实现额外手工逻辑；不再预置 target endpoint 或通过 endpoint 相减取得声明长度。

SAR 字符串和 SAR／GRP 原始数据目标使用 sized 长度；WAR 直接返回 WAV 对象，WAV 仍由自身布局解析，不套 sized-reference 长度限制。`xwar-waves` 直接提取 `xwar-info-entries` 的 WAV／NIL 数组。STM 的 DATA／SEEK／REGN section 只建立各自的全局目标锚点，由 INFO 的原生 pointer 解析样本、SEEK rows／padding 和 REGN entries；SEEK／REGN 不反向读取 stream-info。样本和 REGN 结果仍分别保存在 `xstm-stream-info-sample-data`、`xstm-region-info-data`；SEEK 结果位于 `xstm-info-seek-data`，通过 `xstm-seek-data-rows`／`xstm-seek-data-padding` 访问。INFO 直接传入 REGN 的 channel-count、entry-size 和 count，不回读 INFO 字段。不会在 accessor 或 `read-file` 返回后补做二进制解析。WAR 每个 `xwav-embedded` 入口清空 `$xwav-data-start` 对应的 `pointer-base` cdr，隔离相邻 WAV 的已知位置和 pending callbacks；不改共享 reference 布局。

`$...` 是供其他结构访问的 global position，并支持原生延迟解析；仅当前结构使用的位置和解析变量统一为局部 `%...`。pointer 基址直接传符号，不包 `progn`；typed reference 的调用方通过零宽原生 pointer 获取跨结构基址的数值。生成的引用数组各自捕获局部位置，不会覆盖外层数组基址。pointer 不在字段类型最外层时包原生 `values`，需要立即使用引用目标的字段也使用 `values`。不添加目录跨度、重叠或 sized-reference 子文件长度校验；文件／区块 size 参与尾部 padding 读取，截断 padding 也会导致读取失败，不承诺完整格式校验或受限输入沙箱。

**本库只保证 reader。** ME 同时注册 reader／writer 的编译期端序展开，以保持 binstruct 声明一致；除上述有限的临时 size 回写 smoke 外，不测试、不保证自动生成的 writer 正确性，也不提供文件写入 API。

此前提交 `2e3bda2` 的 ME 优化强制编译测量（不代表本次容器改动的计时）：SBCL 2.6.9／Linux ARM64，`--dynamic-space-size 8192`，新进程先加载依赖，再计时 `(asdf:compile-system :cl-nintendo-ware :force t)`；不含依赖加载、测试和真实文件 smoke。优化前 wall／CPU 为 241.434／241.414 秒，优化后为 65.285／65.287 秒，wall 减少 73.0%（约 3.70 倍）。这是当前机器的单次对照，不是跨环境性能保证；编译仍有未使用变量等 style-warning。

## 验证范围与参考

测试使用 Common Lisp assertions 和独立 binstruct 输入夹具，检查实际字段、引用目标、可空引用、magic／opcode 识别、大小端、嵌套事件及版本分支，不断言生成源码或测试库的 writer。

资源 ID 回归覆盖 C/F × LE/BE 的完整 24 位索引、未知类型与全一 sentinel。库本身仍只负责解析，不进行播放单位转换。

新事件接口通过 [OoT3D-Custom-Sequences](https://github.com/Kewlan/OoT3D-Custom-Sequences) 的 63 个 BCSEQ 文件，共读取 401,232 个顶层事件并完成目标索引转换。此数量包含声明式事件流读取到的非静态可达事件，不等同于旧 reader 的静态遍历计数。另已用实际 `closynth:event-emit` 验证解析所得 note/tempo 对象的类型分派，未接入播放。Citric 的 `guts.bcseq` 有一个开轨目标落在扩展指令内部，索引化时拒绝，不擅自重定位。除下面的 BCSAR 样本外，其他格式与平台主要依赖合成夹具验证，不能据此宣称所有商业游戏兼容。

已通过公开 `read-file` 接口读取 [pmee 的 `mset.bcsar`](https://github.com/bohonghuang/pmee/blob/01f93480dea5e3e99a2e0d658381fd3a2052423d/mset.bcsar)（383,408 字节，CSAR／小端）。pathname、二进制流、octet vector 三种输入均通过；67 个字符串、50 个声音的名称与文件／播放器 ID、音量、序列 bank／起始偏移／优先级，以及显式解析后的 5 个 CWSD item／note 字段与 [DualRip](https://github.com/TetraSsky/DualRip) 独立解析结果交叉核对。测试先通过 `xsar-files` 提取 19 个文件的原始字节，再由调用方显式解析全部文件：5 个 CSEQ（35,225 个顶层事件）、2 个 CWSD、5 个 CBNK、7 个 CWAR；读取 CWAR 时解析其中 34 个 CWAV／34 个声道，其磁盘音频共 273,362 字节。12 个 PCM16 通道直接返回有符号数组，22 个 DSP 通道保留编码帧；library 不进行 ADPCM 解码或播放。另已用这 12 个真实 PCM 数组直接构造 Closynth source 并渲染短窗口。

样本 SHA-256：`e96097ab77e70837cee31acd2c3c132da56a262add4aa8e1fa27d623ecdf7323`。原始文件已纳入 `test/data/mset.bcsar`，由默认 `asdf:test-system` 执行 `test/pmee.lisp` 中的真实归档回归；测试不联网，也不需要外部 checkout。断言 cons 名称／原始数据长度和声音元数据，随后显式解析并验证完整序列事件数量、CWSD 效果参数、project-info，以及全部 CWAV 的符号 codec／采样率／样本数、专用数组类型和对应磁盘音频总量。合成回归覆盖不解析损坏／未知子文件、可选名称、空数据／空引用／外部文件，以及跨端序显式读取；原有 WSD 参数和 SAR project-info tag 回归仍保留。

`test/data/TigerSound.bcsar` 同样保留自 [pmee](https://github.com/bohonghuang/pmee/blob/d70ec1d94bdfd544c12d4ac6ab4f6c722177de1a/TigerSound.bcsar)，804,112 字节，SHA-256 为 `20a0c70542261e6a74f904f1a1f5ed6925bf813b1b0c752e9ecd08b1557d2ed5`。默认真实归档回归覆盖其流声音 track/channel 引用。依据本地 3sf 的 `externals/ntdlib/src/sar/formats.cpp`，CSAR 2.3.0 起在流声音的通道数之后读取 track table 引用；此前布局没有该引用。不能将引用 tag `#x0101` 误作可选参数掩码。归档仍只提取原始子文件，不自动打开外部流文件。
该样本的内部 FILE payload sized reference 使用 tag `0`；在 `#x220c` 内部文件位置的上下文中，reader 接受 `0` 和 `#x1f00`，保留其他 tag 的拒绝行为。3sf 同一解析器也直接使用此记录的 offset／size 定位数据。

`test/data/menu.bcsar` 保留自 [pmee 的提交 `46a0e0859e6eecff2e3765a5779453e567d1d46c`](https://github.com/bohonghuang/pmee/blob/46a0e0859e6eecff2e3765a5779453e567d1d46c/menu.bcsar)，351,392 字节，SHA-256 为 `1017eb4a367cb202ac6018fb432b5654222487149d16242fa7d1f205e63f3eb2`。这是 CSAR 2.0.0／小端样本，默认真实归档回归覆盖 133 个字符串、104 个声音及全部 32 个文件 ID。前两个文件为外部 `stream/BGM_THEME.bcstm`／`stream/BGM_THEME_MONO.bcstm`：保留名称、路径、单／双声道元数据和 `NIL` 数据，不打开外部路径；此版本的流声音没有 track table 引用。归档计数、外部路径、资源别名和内嵌文件长度与 DualRip 独立解析结果核对。

测试显式解析其余 30 个内嵌文件：11 个 CSEQ、2 个 CWSD、6 个 CBNK、3 个 CGRP、8 个 CWAR。断言完整序列事件数量、CWSD pitch／note 波形索引、bank 波形／乐器数量和 CGRP 文件 ID／空数据引用；CWAR 包括空归档与双声道 DSP 波形，共 57 个 CWAV／58 个声道，验证专用音频数组类型及各归档的编码数据字节数，并检查双声道波形的 codec、采样率与样本数。此覆盖不包含外部流文件解析、ADPCM 解码或播放。

```lisp
(nintendo-ware:read-file 'nintendo-ware:xsar
                         (asdf:system-relative-pathname :cl-nintendo-ware #P"test/data/mset.bcsar"))
```

- [ENDIAN.md](ENDIAN.md)：各平台、容器及事件流的端序证据。
- [BCSEQ.md](BCSEQ.md)：3DS 音序、引用和格式资料。
- [Citric Common Structures](https://gota7.github.io/Citric-Composer/specs/common.html)、[Sequences](https://gota7.github.io/Citric-Composer/specs/seq.html)、[Banks](https://gota7.github.io/Citric-Composer/specs/bnk.html)、[Wave Archives](https://gota7.github.io/Citric-Composer/specs/war.html)。
- [Citric Composer 源码](https://github.com/Gota7/Citric-Composer)、[GotaSequenceLib](https://github.com/Gota7/GotaSequenceLib)。
