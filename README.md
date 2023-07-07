# RV64I-cpu-for-class-project
# RV64I CPU设计报告


## 微架构

本次作业的CPU能够运行50条指令：

- R型：add，and，or，sll，slt，sltu，sra，srl，sub，xor，subw，srlw，sraw，addw，sllw，**mulw**
- I型：addi，andi，ori，slli，slti，sltiu，srai，srli，xori，srliw，sraiw，addiw，slliw，jalr，lb，lbu，ld，lh，lhu，lw，lwu
- B型：beq，bge，bgeu，blt，bltu，bne
- S型：sb，sd，sh，sw
- U型：auipc，lui
- J型：jal

本次作业的CPU采用五级流水线实现，数据和控制通路如下图所示：

![image-20230614225257495](https://pic.imgdb.cn/item/64a780791ddac507cccd1d9b.jpg)

CPU由以下子模块组成：

- mini Decoder：在取址阶段对指令进行简单译码，以提前判断指令是否为I型跳转指令jalr、J型跳转指令jal、或B型分支指令。对于指令jalr，提前计算出下一个取指地址PC，对于B型分支指令，使用静态分支预测对下一个取指地址PC进行预测。

- Decoder：在译码阶段对指令进行译码，确定指令类型、立即数、R1、R2、RD等信息。
  - Immediate Extractor：Decoder的子模块，根据指令和类型信息，拼接输出可直接用于ALU计算的立即数。

- Controller：在译码阶段，根据Decoder模块的输出信息，输出包括RDWrite、R1Read、R2Read、ALU_OP、ALU_X1_SRC、ALU_X2_SRC等在内的当前指令的所有控制信号。

- RegFile：CPU的寄存器堆，其中x0保存常数0，不可写。

- I Cache：包含16个Block，每个Block存储1个word，采用FIFO淘汰策略的全相联指令缓存模块，CPU取指令时，拉高I Cache的read请求信号，若read miss，则通过memory access control向Memory请求指令。

- memory access control：作为memory和Cache以及CPU_core之间的数据串并转换模块，将Memory中读取的1Byte串行数据拼接成1/2/4/8 Byte的并行信号传递给CPU_core，或在CPU_core写入Memory时，将CPU_core输出的1/2/4/8 Byte的并行信号转换为1 Byte数据串行写入Memory。

流水线的各个阶段主要实现了以下功能：

- 取指阶段：根据PC的地址访问I Cache取出指令；对取回的指令进行简单译码（ Mini-Decode ）；简单的分支预测；生成取下一条指令的PC。
- 译码阶段：对指令进行译码，确定指令类型、寄存器读写地址、立即数等信息，以及生成后续执行阶段、访存阶段和写回阶段的控制信号。
- 执行阶段：根据ALU_OP选择使用ALU中的加、减、逻辑移位、代数移位、位运算、乘等运算单元进行计算，使用ALU_X1_SRC、ALU_X2_SRC选择从寄存器中读取的数据、立即数、4或0作为输入ALU的操作数。此外，在该阶段能够检测出对于B型分支指令的预测是否出错，能够确定I型跳转指令jalr和B型分支指令的正确跳转地址，判断是否需要冲刷流水线，输出流水线冲刷信号。
- 访存阶段：对load指令，从Memory中读取数据；对Store指令，将寄存堆中的数据写入Memory。
- 写回阶段：使用RDWrite信号选择将访存阶段读取到的Memory数据或执行阶段ALU的计算结果写回到寄存器堆。

## 微处理器特性

### 跳转和转移指令处理

本次作业实现了I型跳转指令jalr、J型跳转指令jal和B型分支指令，对于三种跳转指令采取了不同的处理方式，处理原则是早发现，早应对，尽量减少bubble的产生，从而避免bubble导致的流水线效率降低。

```verilog
    //-----IF stage----------------------------------------------
    //PC寄存器的更新
if(pipeline_update) begin
    if(PC_JUMP_EXECUTE) begin
        // 在EXECUTE阶段确定jalr和Branch的跳转地址
        PC <= Instruction_TYPE_Pipeline_EXE[7]? 
            {64{Branch_COND_true}} & (PC_Pipeline_EXE + Immediate_value_Pipeline_EXE) | // Branch分支预测错误不跳转
            {64{!Branch_COND_true}} & (PC_Pipeline_EXE + 4) // Branch预测错误跳转
            : {64{Instruction_TYPE_Pipeline_EXE[5]}} & ((R1_Data_Selected + Immediate_value_Pipeline_EXE) & 64'hfffffffffffffffe); // I_jalr
    end
    else if(JUMP_TYPE[0]) begin //在IF阶段minidecode，检测立即跳转指令J_jal
        PC <= PC + Imm_JUMP;                     
    end 
    else if(JUMP_TYPE[1]) begin //在IF阶段minidecode，检测Branch指令
        //如果立即数表示的偏移量为负数，意昧着方向为向后跳转，预测为需要跳转。
        PC <= Imm_JUMP[63]? PC + Imm_JUMP: PC+4; 
    end
    else if(Data_Dependency_load_use) begin
        //DECODE段检测到load_use相关时，PC 维持原值
        PC <= PC;
    end
    else begin
        PC <= PC + 4;
    end
end

if(Instruction_TYPE_Pipeline_MEM[2] || Instruction_TYPE_Pipeline_MEM[6])
    if(I_Cache_ready)  
        Instruction_temp <= Instruction_I_Cache;
```

#### IF阶段简单译码

对于J型跳转指令jal，$pc+=sext(offset)$，需要译码取得指令中的立即数才能计算其下一条取指地址，如果在译码阶段再来计算跳转地址，则会浪费掉1条指令；对于B型分支指令，未改进的流⽔线需要在Mem段才会直到是否需要跳转，这样会浪费掉3条指令。

所以，为了尽早地知道是否发⽣跳转或转移，把对于跳转和转移指令的检测提早到取指阶段，对取回的指令进行简单译码，用于检测跳转指令jalr、jal以及Branch指令；此外，在IF阶段添加一个加法器，使用简单译码得到的pc地址偏移的立即数，计算jal指令的跳转地址，或Branch指令的转移地址预测值。

从下面仿真图中可以看出，在IF阶段，当PC地址取出的指令为jal跳转指令，跳转指令指示信号JUMP_TYPE对应位拉高，Imm_JUMP指示跳转偏移量，根据当前PC和Imm_JUMP计算出的跳转目标地址用于更新PC寄存器，从而保证IF阶段下一拍能直接取到正确的指令。

![image-20230615120250076](https://pic.imgdb.cn/item/64a780fd1ddac507ccce1f84.jpg)

#### 静态分支预测

对于带条件直接跳转的Branch指令，使用静态预测，由于在实际的汇编程序中向后分支跳转的情形要多于向前跳转的情形， 譬如常见的for 循环生成的汇编指令往往使用向后跳转的分支指令。因此向后跳转则预测为需要跳，否则预测为不需要跳，具体而言，如果立即数表示的偏移量（ offset ） 为负数（ 最高位符号位为1 ， 意昧着方向为向后跳转，预测为需要跳转。

从下面仿真图可以看出，在IF阶段，当PC地址取出的指令为Branch指令，JUMP_TYPE对应位拉高，立即数表示的偏移量（ offset ）的符号位为负，预测向后跳转，使用下次取指的目标地址预测值更新PC寄存器。在EXE阶段可以判断出预测正确，不需要冲刷流水线。

![image-20230615121713940](https://pic.imgdb.cn/item/64a7811e1ddac507ccce672d.jpg)

#### EXE阶段确定跳转目标

相比于理论课讲的未改进的流⽔线转移是否发⽣在Mem段才能确定，本次作业的CPU作出改进，在EXE阶段额外添加操作数比较器，将Branch转移和jalr跳转的判断提前到EXE段，当分支指令预测失败或发生jalr跳转时，最多损失2条指令，不提前判断，会浪费3条指令（MEM段）。在EXE阶段检测转移不需要添加专用的bypass电路解决寄存器操作数前后相关的问题，可以与解决ALU的forwarding共用一个电路。

在EXE阶段检测到Branch指令预测错误时，需重新计算正确PC；对于jalr指令，$pc=(x[rs1]+sext(offset))\&!1$，考虑到可能出现的寄存器数据相关，也需要在EXE阶段计算跳转的目标PC地址，因此需要在EXE阶段添加额外的加法器用于计算新的PC地址。当检测到jalr指令或Branch指令预测错误时，需冲刷ID和EXE级流水线，以废除在Jalr或Branch指令之后进入的两条错误指令。

从下面仿真图可以看出，在EXE阶段检测出了jalr信号，跳转指示信号PC_JUMP_EXECECUTE信号拉高，在此阶段，jalr已经进入了两条需要废除的错误指令，因此IF/ID和ID/EXE级流水线寄存器的冲刷信号flush_ID和flush_EXE信号均拉高，可以看到，下一拍IF/ID和ID/EXE级流水线被冲刷，正确的取指地址被送到PC，开始取jalr或Branch指令之后正确的下一条指令。

![image-20230615120047323](https://pic.imgdb.cn/item/64a781311ddac507ccce8ec3.jpg)

下面的仿真图展示了Branch分支指令预测出错的情况，具体过程与jalr指令类似。

![image-20230615135950062](https://pic.imgdb.cn/item/64a781421ddac507ccceb109.jpg)

### 采用FIFO淘汰策略的I Cache

由于Memory一拍只能读取1 Byte数据，因此加入I Cache，使得CPU直接从Cache取指令，减少直接从Memory取指需要等待的时间，是很有必要的。本次作业的CPU采用了具有16个Block的全相联Cache，每个Block包含1个word，最多可以存储16条指令。当Cache存满时，采用先进先出的替换策略。

从以下仿真截图看出，后半段cache hit时CPU的运行速度显著快于前半段Cache miss时的运行速度。

![image-20230615142226904](https://pic.imgdb.cn/item/64a781571ddac507cccedbb8.jpg)

从下表看出，加入Cache后，运行fib和fib_bit_count的速度具有显著的提升，因此这两个benchmark中的循环执行指令的条数较少，sm4的循环执行的指令条数多达64条，而Cache最多只能存储16个word的数据，因此Cahce无法改善sm4的运行表现，由于Cache握手的等待时间反而略微恶化了sm4的运行时间。

| benchmark     | 不加I Cache周期数 | 加I Cache后周期数 |
| ------------- | ----------------- | ----------------- |
| fib           | 490               | 350               |
| fib_bit_count | 8460              | 4250              |
| sm4           | 43460             | 49300             |

### 冒险处理

#### 数据相关

##### EXE段数据相关

对EXE段的数据相关，判断条件为：

```verilog
        Data_Dependency_1a = !Instruction_TYPE_Pipeline_MEM[2] //不是I_TYPE_LOAD类指令
                        &&  RD_Pipeline_MEM != 0 //x0无法写入
                        &&  R1_Pipeline_EXE == RD_Pipeline_MEM
                        &&  RDWrite_Pipeline_MEM //需要写回RD
                        &&  R1Read_Pipeline_EXE; //需要读取R1
```

#### MEM段数据相关

对MEM段数据相关判断条件为：

```verilog
        Data_Dependency_2a =  RD_Pipeline_WB != 0 //x0无法写入
                        &&  R1_Pipeline_EXE == RD_Pipeline_WB
                        &&  RDWrite_Pipeline_WB //需要写回RD
                        &&  R1Read_Pipeline_EXE //需要读取R1
                        &&  R1_Pipeline_EXE != RD_Pipeline_MEM; //不是MEM／WB段数据相关
```

EXE段数据相关和MEM段数据相关均可采用数据前馈forwarding解决，选择输入ALU的值为寄存器中数据还是MEM阶段或WB阶段回传的数据。

#### WB段数据相关

WB段数据相关判断条件为：

```verilog
Data_Dependency_3a = RD_Pipeline_WB != 0 //x0无法写入
                        &&  Instruction[19:15] == RD_Pipeline_WB
                        &&  RDWrite_Pipeline_WB //需要写回RD
                        &&  R1Read //需要读取R1
                        &&  R1_Pipeline_EXE != RD_Pipeline_MEM //不是MEM／WB段数据相关
                        &&  R1_Pipeline_EXE != RD_Pipeline_WB; //不是MEM／WB段数据相关  
```

WB段的数据相关可以通过在译码阶段加入bypass电路解决。若发生WB段数据相关，则将WB阶段准备写回的数据直接写入ID/EXE级的流水线寄存器。

#### Load_use相关

Load_use相关尽早发现，有利于插泡。在ID阶段检测Load_use相关的条件为：

```verilog
  Data_Dependency_load_use = Instruction_TYPE_Pipeline_EXE[2] // I_TYPE_LOAD类指令
                        &&  RD_Pipeline_EXE != 0  
                        &&  ((Instruction[19:15] == RD_Pipeline_EXE && R1Read) || (Instruction[24:20] == RD_Pipeline_EXE && R2Read));
```

当检测到Load_use相关时，采取的应对方法：先插入1个bubble，阻塞PC和IF/ID段寄存器的更新，使IF段和ID段原地踏步一拍，然后使用forwarding，解决MEM段数据相关。

值得注意的是，EXE段数据相关的检测条件排除了load类指令，因为load_use相关的后续处理不可能引起EXE段数据相关，但load_use可能出现WB段数据相关，或者插一个bubble后，会出现MEM段数据相关。

### 流水线更新

设置流水线更新信号pipeline_update，更加方便地控制流水线阻塞或更新。

```verilog
 if(Instruction_TYPE_Pipeline_MEM[2] || Instruction_TYPE_Pipeline_MEM[6]) 
            pipeline_update = (state) & Mem_ready;  //若MEM stage没有Memory访问需求，待访问完成，流水线寄存器可更新
        else //MEM stage没有Memory访问需求
            pipeline_update = (!state) & I_Cache_ready; //取值完成，流水线寄存器可更新
```

检测MEM阶段是否有访问Memory的请求，如果MEM阶段需要访问Memory，则对每级流水线插入bubble，阻塞流水线运行，直到Memory读写完成传回Mem_ready信号才再次更新流水线。

## 仿真验证

### 仿真波形

以下截图中写入0x1000的最终结果使用十进制显示。

#### fib

![image-20230614204854122](https://pic.imgdb.cn/item/64a781731ddac507cccf19c9.jpg)

#### fib_bit_count

![image-20230614205015771](https://pic.imgdb.cn/item/64a7818e1ddac507cccf5513.jpg)

#### sm4

![image-20230614204403644](https://pic.imgdb.cn/item/64a781d01ddac507cccff36f.jpg)

### FPGA验证

使用数字集成电路设计与实践课程的测试平台进行验证，使用串口回传计算结果

#### 斐波那契数列计算程序

计算并输出斐波那契数列前十个数字。每个数字之后都跟一个0x0A代表换行。

![image-20230615153131506](https://pic.imgdb.cn/item/64a782021ddac507ccd05bf6.jpg)

#### 最大公约数计算程序

 计算：
1） 35 与 15 的最大公约数
2） 17 与 51 的最大公约数
3） 23 与 115 的最大公约数
4） 73 与 37 的最大公约数

![image-20230615153207045](https://pic.imgdb.cn/item/64a782231ddac507ccd0acad.jpg)

#### 卷积计算程序

计算：

<img src="C:\Users\27950\AppData\Roaming\Typora\typora-user-images\image-20230615154217301.png" alt="image-20230615154217301" style="zoom: 50%;" />

![image-20230615153246842](https://pic.imgdb.cn/item/64a782341ddac507ccd13eb3.jpg)

## DC综合报告

run.tcl中约束如下：

<img src="https://pic.imgdb.cn/item/64a782481ddac507ccd16405.jpg" alt="image-20230614211014205" style="zoom:65%;" />

### timing report

<img src="C:\Users\27950\AppData\Roaming\Typora\typora-user-images\image-20230614210537820.png" alt="image-20230614210537820" style="zoom:54%;" />

### area report

<img src="C:\Users\27950\AppData\Roaming\Typora\typora-user-images\image-20230614210619195.png" alt="image-20230614210619195" style="zoom:58%;" />

### power report

![image-20230614210658459](C:\Users\27950\AppData\Roaming\Typora\typora-user-images\image-20230614210658459.png)

## 性能总结

| benchmark     | 时钟周期数 | 周期数×时钟周期    |
| ------------- | ---------- | ------------------ |
| fib           | 350        | 350×4ns=1400ns     |
| fib_bit_count | 4250       | 4250×4ns=17000ns   |
| sm4           | 49300      | 49300×4ns=197200ns |

| 面积   | 时钟频率 | 功耗     |
| ------ | -------- | -------- |
| 672611 | 250M     | 111.36mW |



