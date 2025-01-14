import 'dart:math';
import 'package:flutter/material.dart';
import 'main.dart';

enum MemoryAlgo { First_Fit, Next_Fit, Best_Fit, Worst_Fit }

const int MEMORY_SIZE = 50;

String getMemoryData(DataChoice? choice) {
  switch (choice) {
    case DataChoice.First:
      return "1,6;21,6;3,6;4,2;1,4;3,2;1,2;4,1;22,3";
    default:
      return "";
  }
}

Widget runMemoryAlgo(MemoryAlgo algo, StringBuffer log, List<List<num>> rawProcesses) {
  List<MemoryProcess> processes = [];
  for (int i = 0; i < rawProcesses.length; i++) {
    processes.add(MemoryProcess(rawProcesses[i], MemoryProcess.generateName(i)));
  }
  var memory = Memory(log);
  switch (algo) {
    case MemoryAlgo.First_Fit:
      return memoryFit(processes: processes, memory: memory, log: log);
    case MemoryAlgo.Next_Fit:
      return memoryFit(processes: processes, memory: memory, log: log ,reverseChunkPriority: true);
    case MemoryAlgo.Best_Fit:
      return memoryFit(processes: processes, memory: memory, log: log, sortByChunkSize: true);
    case MemoryAlgo.Worst_Fit:
      return memoryFit(processes: processes, memory: memory, log: log, reverseChunkPriority: true, sortByChunkSize: true);
  }
}

class MemoryProcess {
  static int charA = 'A'.codeUnitAt(0);
  late String name;
  Color? color;
  late num size;
  late num time;
  num? regStart;
  num? regEnd;

  MemoryProcess(List<num> request, String name) {
    this.name = name;
    size = request[0];
    time = request[1];
    color = Color((Random(name.hashCode).nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0);
  }

  void setReg(regStart, regEnd) {
    this.regStart = regStart;
    this.regEnd = regEnd;
  }

  static String generateName(int index) {
    return String.fromCharCode(charA + index);
  }

  @override
  String toString() {
    return "$name: $size,$time";
  }
}

class Memory {
  final List<bool> regs = List.generate(MEMORY_SIZE, (index) => true);
  final StringBuffer log;
  num time = 1;
  List<MemoryProcess> processes = [];

  Memory(this.log);

  List<List<num>> getFreeChunks() {
    List<List<num>> chunks = [];
    for (var i = 0; i < regs.length; i++) {
      if (regs[i]) {
        List<num> chunk = [i];
        while (i + 1 < regs.length) {
          if (!regs[i + 1]) break;
          i++;
        }
        chunk.add(i);
        chunks.add(chunk);
      }
    }
    return chunks;
  }

  void addProcess(MemoryProcess process) {
    assert(process.regStart != null && process.regEnd != null);
    processes.add(process);
    for (var i = process.regStart!; i <= process.regEnd!; i++) {
      regs[i as int] = false;
    }
  }

  void tick() {
    log.write("\n######$time - $processes");
    List<MemoryProcess> removeList = [];
    for (var process in processes) {
      process.time--;
      if (process.time == 0) {
        for (var i = process.regStart!; i <= process.regEnd!; i++) {
          regs[i as int] = true;
        }
        removeList.add(process);
      }
    }
    for (var process in removeList) {
      processes.remove(process);
      log.write("\n######Process $process finished");
    }
    time++;
  }

  bool isEmpty() {
    return processes.isEmpty;
  }
}

Widget memoryFit({required List<MemoryProcess> processes, required Memory memory, required StringBuffer log, bool reverseChunkPriority = false, bool sortByChunkSize = false}) {
  log.write("Starting ${sortByChunkSize ? reverseChunkPriority ? "worst-fit" : "best-fit" : reverseChunkPriority ? "last-fit" : "first-fit"} with $processes");
  List<TableRow> resultList = [];
  for (var process in processes) {
    var chunks = memory.getFreeChunks();
    if (sortByChunkSize & chunks.isNotEmpty) {
      chunks.sort((List<num> a, List<num> b) {
        num compare = (a[1] - a[0]).compareTo(b[1] - b[0]);
        if (reverseChunkPriority) {
          compare *= -1;
        }
        if (compare == 0) {
            compare = a[0].compareTo(b[0]);
        }
        return compare as int;
      });
    }
    if(!sortByChunkSize && reverseChunkPriority){
      chunks = chunks.reversed.toList();
    }
    log.write("\nTrying to add process $process to free chunks $chunks");
    bool added = false;
    for (var chunk in chunks) {
      if (chunk[1] - chunk[0] >= process.size - 1) {
        process.setReg(chunk[0], chunk[0] + process.size - 1);
        log.write("\n   Added process $process to range [${process.regStart}, ${process.regEnd}]");
        memory.addProcess(process);
        added = true;
        resultList.add(rowFromMemory(memory, process.toString(), false, false));
        memory.tick();
        break;
      }
    }
    if (!added) {
      log.write("\n!---Could not add process $process---!");
      resultList.add(rowFromMemory(memory, process.toString(), true, true));
      log.write("\nFailed to complete ${sortByChunkSize ? reverseChunkPriority ? "worst-fit" : "best-fit" : reverseChunkPriority ? "last-fit" : "first-fit"}");
      return resultFromList(resultList);
    }
  }
  while (!memory.isEmpty()) {
    resultList.add(rowFromMemory(memory, "-", false, false));
    memory.tick();
  }
  resultList.add(rowFromMemory(memory, "-", true, false));
  log.write("\nFinished ${sortByChunkSize ? reverseChunkPriority ? "worst-fit" : "best-fit" : reverseChunkPriority ? "last-fit" : "first-fit"} successfully");
  return resultFromList(resultList);
}

class MemoryResult extends StatelessWidget {
  final List<TableRow> list;
  const MemoryResult(this.list, {super.key});

  @override
  Widget build(BuildContext context) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal, // Add horizontal scroll
        child: IntrinsicWidth(
          child: Table(
            children: list,
            columnWidths: {
              0: FixedColumnWidth(60), // Time column width
              1: FixedColumnWidth(100), // Process column width
              for (int i = 2; i < MEMORY_SIZE + 2; i++) i: FixedColumnWidth(30), // Uniform width for memory cells
            },
          ),
        ),
      );
  }
}

MemoryResult resultFromList(List<TableRow> list) {
  List<TableCell> headerCellList = List.generate(
    MEMORY_SIZE,
    (index) => TableCell(
      verticalAlignment: TableCellVerticalAlignment.bottom,
      child: Container(
        alignment: Alignment.bottomCenter,
        child: Center(
          child: Text(
            index.toString(),
            maxLines: 1,
            overflow: TextOverflow.fade,
            style: const TextStyle(fontFamily: 'Nutino',),
          ),
        ),
      ),
    ),
  );
  headerCellList.insertAll(
    0,
    [
      TableCell(
        verticalAlignment: TableCellVerticalAlignment.bottom,
        child: Container(
          alignment: Alignment.centerLeft,
          child: const Center(
            child: Text(
              "Time",
              style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Nutino'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
      TableCell(
        child: Container(
          alignment: Alignment.center,
          child: const Center(
            child: Text(
              "Added Process",
              style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Nutino'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    ],
  );

  list.insert(0, TableRow(children: headerCellList));
  return MemoryResult(list);
}

TableRow rowFromMemory(Memory memory, String addedProcess, bool finalRow, bool failed) {
  Color? freeColor = Colors.grey[600];
  if (finalRow) {
    if (failed) {
      freeColor = Colors.red;
    } else {
      freeColor = Colors.green;
    }
  }
  List<TableCell> cellList = List.generate(
    MEMORY_SIZE,
        (index) => TableCell(
      child: Container(
        width: 30, // Fixed width for consistency
        height: 30,
        color: freeColor,
        alignment: Alignment.center,
        child: Center(child: Text(finalRow ? "" : "-", style: const TextStyle(fontFamily: 'Nutino'))),
      ),
    ),
  );

  if (!finalRow) {
    for (var process in memory.processes) {
      List<TableCell> processCellList = List.generate(
        process.size as int,
        (index) => TableCell(
          child: Container(
            alignment: Alignment.center,
            color: process.color,
            child: Center(
              child: Text(
                process.name,
                style: TextStyle(
                  color: process.color!.computeLuminance() > 0.5 ? Colors.black : Colors.white,fontFamily: 'Nutino',
                ),
              ),
            ),
          ),
        ),
      );
      cellList.replaceRange(process.regStart as int, process.regEnd! + 1 as int, processCellList);
    }
  }
  cellList.insertAll(
    0,
    [
      TableCell(
        child: Container(
          alignment: Alignment.centerLeft,
          child: Center(
            child: Text(
              !failed && finalRow ? '' : memory.time.toString(),style: const TextStyle(fontFamily: 'Nutino',),
            ),
          ),
        ),
      ),
      TableCell(
        child: Container(
          alignment: Alignment.center,
          child: Center(
            child: Text(
              !failed && finalRow ? 'Done' : addedProcess,
              maxLines: 1,
              overflow: TextOverflow.fade,
            ),
          ),
        ),
      ),
    ],
  );
  return TableRow(children: cellList, decoration: BoxDecoration(color: finalRow ? freeColor : Colors.transparent));
}
