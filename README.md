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
sbcl --non-interactive --eval '(ql:quickload :cl-nintendo-ware :silent t)' \
  --eval '(asdf:test-system :cl-nintendo-ware)'
```

包名 `cl-nintendo-ware`，唯一昵称 `nintendo-ware`。

## 读取文件

`read-file` 接受 pathname、文件名字符串、二进制流或字节向量。类型可用 `:auto`、规范结构名称或 C/F 格式名称，例如 `:sound-sequence`、`:cseq`、`:bfseq`。

```lisp
(let* ((file (nintendo-ware:read-file :auto #P"/path/to/music.bcseq"))
       (events (nintendo-ware:sound-sequence-events file)))
  (loop for event across events
        when (typep event 'nintendo-ware:sequence-event-note)
          collect (list (nintendo-ware:sequence-event-note-key event)
                        (nintendo-ware:sequence-event-note-duration event))))
```

每个完整文件都从自己的 magic 和 BOM 选择 reader，包括内嵌文件。头中的文件大小、区块范围、引用类型、偏移和数组数量在读取目标前验证；生成的文件读取入口不需要 `limit` 或端序参数。流输入先规范化为字节向量，随后使用 binstruct 的原生向量读取和边界检查。

| 模块 | 结构 | 文件 magic |
|---|---|---|
| `sound/sequence.lisp` | `sound-sequence` | CSEQ / FSEQ |
| `sound/wave.lisp` | `sound-wave` | CWAV / FWAV |
| `sound/wave-archive.lisp` | `wave-archive` | CWAR / FWAR |
| `sound/bank.lisp` | `sound-bank` | CBNK / FBNK |
| `sound/wave-sound-data.lisp` | `wave-sound-data` | CWSD / FWSD |
| `sound/stream.lisp` | `sound-stream` | CSTM / FSTM |
| `sound/archive.lisp` | `sound-archive` | CSAR / FSAR |
| `sound/group.lisp` | `sound-group` | CGRP / FGRP |

共用解析布局不等于保证所有游戏、版本和编码组合兼容。原始 ID、引用、可选字段、DATA 及填充保留；空引用为 `NIL`。外部档案路径只读取为字符串，绝不自动打开。

## 事件与端序

`sound-sequence-events` 返回具体事件对象的向量，可直接以 `sequence-event-note`、`sequence-event-tempo` 等类型进行 CLOS 分派。字段直接表达音高、力度、时值、数值及内嵌 `sub-event`；不暴露 opcode、事件原始字节或二进制位置。开轨、跳转、调用的 `index` 和标签的 `label-entry-index` 均为该向量的零基索引。

`define-sequence-event` 仿照 Nitro 的 `define-sseq-event`，从同一份字段声明生成完整和 `/partial` 布局；random/variable 内嵌的子事件使用 `/partial`，省略最后一个参数，而不是最后一个字节。多字节事件标记不产生额外的消费对象，reader 直接返回具体事件类型。

事件标记参数 `event-bytes` 用 `ensure-list` 统一：单字节写 `(wait #x80)`，多字节写 `(mod2-phase (#xf0 #xa1))`，也支持任意更长的固定字节序列。每个标记字节生成一个独立的 `satisfies`/`eql` 声明；没有 `extended` 标志或专用扩展事件 union。`/partial` 由外层提供已消费的第一个标记字节，其余标记字节仍逐个校验，只省略最后一个参数。音符的首字节是音高，因此单独声明其范围布局。

事件选择使用 binstruct 的 `(or (事件类型) ...)` union，各类型的首字节声明校验操作码；不使用运行时 opcode 描述表或手写事件读取循环。`defbinio` 仅用于完整文件的最终代码生成，不提供事件级二进制读取 API。

容器 BOM 与事件字节序分别处理：CSEQ 事件固定大端；Wii U FSEQ 为大端；Switch FSEQ 为小端。文件声明选择事件流布局，消费端无需处理端序。所有平台共享事件声明，不施加平台 opcode 白名单。

CSTM SEEK 上下文固定小端；当前 FSTM SEEK 布局按 Citric 的参考实现使用大端上下文，独立于区块头 BOM。编码音频始终保留原始字节，不因容器换端序而交换音频 payload。

## 声明模式

`define-nintendo-ware-file`、`define-nintendo-ware-section` 参考 `cl-nitro`，复用公共文件／区块头；现代容器按 sized reference 定位区块，而非假设区块连续排列。

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

也接受 binstruct 风格的可选参数列表；生产 schema 最多三个参数。递归类型需先声明端序分派，见 `sequence-event-union`。打包进一个整数的子字段若在两端字节位置不同，则显式声明共享 Lisp 类型的两种布局，不假装字段顺序相同。

相对引用使用 `reference-to`、`bounded` 和原生 `pointer`。引用 tag、空偏移、最小目标跨度均先验证；不为每个格式生成一套长参数引用包装。

**本库只保证 reader。** 不为 writer 增加端序钩子，不测试、不保证自动生成的 writer 正确性；保留正常 binstruct 声明与指针信息，方便将来实现。

## 验证范围与参考

测试使用 Common Lisp assertions 和独立 binstruct 输入夹具，检查实际字段、引用目标、可空引用、大小端、嵌套事件、文件边界及版本分支，不断言生成源码或测试库的 writer。

新事件接口通过 [OoT3D-Custom-Sequences](https://github.com/Kewlan/OoT3D-Custom-Sequences) 的 63 个 BCSEQ 文件，共读取 401,232 个顶层事件并完成目标索引转换。此数量包含声明式事件流读取到的非静态可达事件，不等同于旧 reader 的静态遍历计数。另已用实际 `closynth:event-emit` 验证解析所得 note/tempo 对象的类型分派，未接入播放。Citric 的 `guts.bcseq` 有一个开轨目标落在扩展指令内部，索引化时拒绝，不擅自重定位。其他格式与平台主要依赖合成夹具验证，不能据此宣称所有商业游戏兼容。

- [ENDIAN.md](ENDIAN.md)：各平台、容器及事件流的端序证据。
- [BCSEQ.md](BCSEQ.md)：3DS 音序、引用和格式资料。
- [Citric Common Structures](https://gota7.github.io/Citric-Composer/specs/common.html)、[Sequences](https://gota7.github.io/Citric-Composer/specs/seq.html)、[Banks](https://gota7.github.io/Citric-Composer/specs/bnk.html)、[Wave Archives](https://gota7.github.io/Citric-Composer/specs/war.html)。
- [Citric Composer 源码](https://github.com/Gota7/Citric-Composer)、[GotaSequenceLib](https://github.com/Gota7/GotaSequenceLib)。
