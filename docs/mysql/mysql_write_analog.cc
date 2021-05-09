// 本文件模拟了MySQL的write_ahead优化；命令说明：echo 3 >/proc/sys/vm/drop_caches 用于清空缓存，
// 使用write_ahead优化写出文件，指定write_ahead_size是8192：g++ -O3 -DWRITE_AHEAD append_write.cc -o append_write && echo 3 >/proc/sys/vm/drop_caches && time ./append_write ./tmp.txt 8192
// 使用write_ahead优化写出文件，指定write_ahead_size是8193：g++ -O3 -DWRITE_AHEAD append_write.cc -o append_write && echo 3 >/proc/sys/vm/drop_caches && time ./append_write ./tmp.txt 8193
// 不使用write_ahead优化写出文件：g++ -O3 append_write.cc -o append_write && echo 3 >/proc/sys/vm/drop_caches && time ./append_write ./tmp.txt

#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <fcntl.h>
#include <string.h>

// 写出文件路径
char filepath[128];
// 每次写出数据量，实际写出数据的时候每次写出的数据量都是不一样的，这里为了模拟使用固定的值，每次都写出固定的数据
uint32_t len_per = 512;
// 总共要写出的文件大小；PS：如果设置的不是len_per的整数倍的话该值不是精确的
const uint64_t file_size = 1024 * 1024 * 1024 * 1ul;
// 等效于MySQL的innodb_log_write_ahead_size
uint64_t write_ahead_size = 1024 * 8;


void usage() {
  fprintf(stderr, "usage:\n\t./append_write filepath [write_ahead_size] [len_per]\n");
}

int main(int argc, char* argv[]) {
  if (argc > 4 || argc < 2) {
    usage();
    return -1;
  }

  strcpy(filepath, argv[1]);

  if (argc == 3) {
    write_ahead_size = atol(argv[2]);
  } else if (argc == 4) {
    len_per = atoi(argv[3]);
  }

  // 注意：实际上len_per是可以比write_ahead_size大的，但是为了简化处理，这里限制len_per不能比write_ahead_size大；
  if (len_per > write_ahead_size) {
    fprintf(stderr, "参数设置错误\n");
    return -1;
  }

  // 该数组不会进行填充，仅仅作为模拟用，模拟实际存储要写出的数据的buffer
  char buf[len_per < 4096 ? 4096 : len_per];
  // 模拟write_ahead_buffer
  char write_ahead_buffer[write_ahead_size];


  int32_t fd = open(filepath, O_RDWR);
  if (fd == -1) {
    fprintf(stderr, "create new file failed, errno: %d\n", errno);
    return -1;
  }

  fprintf(stderr, "当前要写出的文件路径: %s\n", filepath);
  fprintf(stderr, "当前要写出文件总大小（单位byte）：%d \n", file_size);
  fprintf(stderr, "当前每次写出数据大小（单位byte）：%d\n", len_per);
  fprintf(stderr, "当前write_ahead_size（单位byte）: %d\n", write_ahead_size);
  fprintf(stderr, "start writing...\n");

  int32_t point = 0;
  bool init = true;
  for (uint64_t sum = 0; sum < file_size; sum += len_per) {
#ifdef WRITE_AHEAD
    // 模拟write_ahead
    point += len_per;
    if (point > write_ahead_size) {
      // 如果当前累计长度大于write_ahead_size，那么说明当前数据在两个page上了，将数据分为两部分，前半段的page cache肯定已经有了，后半段因为
      // 可能不存在page cache，所以用write_ahead的方式写出
      // 前半段数据长度
      uint32_t preceding_chapters = len_per - point + write_ahead_size;
      // 后半段数据长度
      uint32_t rest_chapters = point - write_ahead_size;

      // 可能本次正好在起始位置，所以前半段等于0
      if (preceding_chapters > 0) {
        // 将数据前半段写出
        if (pwrite(fd, buf, preceding_chapters, sum) != preceding_chapters) {
          fprintf(stderr, "write failed, errno: %d\n", errno);
          close(fd);
          return -1;
        }
      }

      // 数据后半段要通过write_ahead机制写出
      // 要写出的数据copy到write_ahead_buffer中，因为前半段数据已经写出了，所以这里只需要copy后半段就行
      memcpy(write_ahead_buffer, buf + preceding_chapters, rest_chapters);
      // 模拟将真实数据后边的数据填0，防止有脏数据
      memset(write_ahead_buffer + rest_chapters, 0, write_ahead_size - rest_chapters);
      // 后半部段写出，注意，write_ahead的时候需要将整个write_ahead_buffer写出
      if (pwrite(fd, write_ahead_buffer, write_ahead_size, sum + preceding_chapters) != write_ahead_size) {
        fprintf(stderr, "write failed, errno: %d\n", errno);
        close(fd);
        return -1;
      }
      point = point - write_ahead_size;
    } else {
      if (init) {
        // 初始化的时候要进行一次write_ahead，其实这个无所谓，因为总数据量远远大于第一次初始化的数据，即使第一次写出的时候没有write_ahead
        // 对整体性能影响也不明显
        init = false;

        memcpy(write_ahead_buffer, buf, len_per);
        memset(write_ahead_buffer + len_per, 0, write_ahead_size - len_per);

        if (pwrite(fd, write_ahead_buffer, len_per, sum) != len_per) {
          fprintf(stderr, "write failed, errno: %d\n", errno);
          close(fd);
          return -1;
        }
      } else {
        // 直接写出，只要能走到这里说明肯定进行过write_ahead了，肯定已经有page cache了
        if (pwrite(fd, buf, len_per, sum) != len_per) {
          fprintf(stderr, "write failed, errno: %d\n", errno);
          close(fd);
          return -1;
        }
      }

    }
#else
    // 普通写出
    if (pwrite(fd, buf, len_per, sum) != len_per) {
      fprintf(stderr, "write failed, errno: %d\n", errno);
      close(fd);
      return -1;
    }
#endif

  }

  fprintf(stderr, "finish writing...\n");

  close(fd);
  return 0;
}
