//
//  main.m
//  MachOExploration
//
//  Created by chenzheng on 2020/5/8.
//  Copyright © 2020 CST. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <stdlib.h>

uint32_t read_magic(FILE *obj_file, int offset) {
  uint32_t magic;
  fseek(obj_file, offset, SEEK_SET);
  fread(&magic, sizeof(uint32_t), 1, obj_file);
  return magic;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
        /**
         读取 Header
         */
        NSString *machoFilePath = @"/Users/chenzheng/Documents/Qiubai/GitHub/MachOExploration/HelloWorld/HelloWorld";
        
        NSData *resultData = [NSData dataWithContentsOfFile:machoFilePath];
        NSData *header = [resultData subdataWithRange:NSMakeRange(0, 4)];
        uint32_t magic1;
        [resultData getBytes:&magic1 length:sizeof(uint32_t)];
        NSLog(@"%X",magic1);
        
        FILE *fp = fopen(machoFilePath.UTF8String, "r");
        uint32_t magic = read_magic(fp, 0);
        NSLog(@"%X",magic);
        
        
        
        
        
        
        NSInteger i = 0;
        while (i <= sizeof(uint32_t) && !feof(fp)) {
            NSLog(@"%x",fgetc(fp));
            i++;
        }
        
        magic = fgetc(fp);
//        magic = (uint32_t *)fp;
//        NSLog(@"magic = %@",magic);
    }
    return 0;
}
