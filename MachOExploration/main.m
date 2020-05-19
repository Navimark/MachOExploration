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

void *load_bytes(FILE *fp, int offset, int size)
{
    void *buf = calloc(1, size);
    if(!buf) {
        return NULL;
    }
    fseek(fp, offset, SEEK_SET);
    fread(buf, size, 1, fp);
    return buf;
}

struct mach_header_64* load_header_64(FILE *fp)
{
    struct mach_header_64 *header = load_bytes(fp, 0, sizeof(struct mach_header_64));
    NSLog(@"magic:%X",header->magic);   // FEEDFACF
    NSLog(@"cputype:%d",header->cputype); // 16777228 : CPU_TYPE_ARM64;
    NSLog(@"cpusubtype:%d",header->cpusubtype); // 0 : CPU_SUBTYPE_VAX_ALL;
    NSLog(@"filetype:%d",header->filetype); // 2 : MH_EXECUTE;
    NSLog(@"ncmds:%d",header->ncmds); // 21
    NSLog(@"sizeofcmds:%d",header->sizeofcmds); // 2704
    NSLog(@"flags:%d",header->flags); // 2097285 = (flags & MH_TWOLEVEL) | (flags & MH_PIE) | (flags & MH_DYLDLINK) | (flags & MH_NOUNDEFS)
    NSLog(@"reserved:%d",header->reserved); // 0
    return header;
}

void segment_64_load_handler(FILE *fp, uint32_t offset)
{
    struct segment_command_64 *sc_64 = load_bytes(fp, offset, sizeof(struct segment_command_64));
    NSLog(@"cmd:%d",sc_64->cmd);
    NSLog(@"cmdsize:%d",sc_64->cmdsize);
    NSLog(@"segname:%s",sc_64->segname);
    NSLog(@"vmaddr:%llu",sc_64->vmaddr);
    NSLog(@"vmsize:%llu",sc_64->vmsize);
    NSLog(@"fileoff:%llu",sc_64->fileoff);
    NSLog(@"filesize:%llu",sc_64->filesize);
    NSLog(@"maxprot:%d",sc_64->maxprot);
    NSLog(@"initprot:%d",sc_64->initprot);
    NSLog(@"nsects:%d",sc_64->nsects);
    NSLog(@"flags:%d",sc_64->flags);
    free(sc_64);
}

void dyld_info_command_handler(FILE *fp, uint32_t offset)
{
    struct dyld_info_command *dyld_c = load_bytes(fp, offset, sizeof(struct dyld_info_command));
    NSLog(@"cmd:%@",@(dyld_c->cmd)); // 2147483682 = (0x22 | LC_REQ_DYLD) = (0x22 | 0x80000000) = LC_DYLD_INFO_ONLY
    NSLog(@"cmdsize:%d",dyld_c->cmdsize);
    NSLog(@"rebase_off:%d",dyld_c->rebase_off);
    NSLog(@"rebase_size:%d",dyld_c->rebase_size);
    NSLog(@"bind_off:%d",dyld_c->bind_off);
    NSLog(@"bind_size:%d",dyld_c->bind_size);
    NSLog(@"weak_bind_off:%d",dyld_c->weak_bind_off);
    NSLog(@"weak_bind_size:%d",dyld_c->weak_bind_size);
    NSLog(@"lazy_bind_off:%d",dyld_c->lazy_bind_off);
    NSLog(@"lazy_bind_size:%d",dyld_c->lazy_bind_size);
    NSLog(@"export_off:%d",dyld_c->export_off);
    NSLog(@"export_size:%d",dyld_c->export_size);
}

void load_commands_handler(struct load_command *lc_base, FILE *fp, uint32_t offset)
{
    NSLog(@"--------------------------------");
    uint32_t cmd = lc_base->cmd;
    switch (cmd) {
        case LC_SEGMENT_64:
            segment_64_load_handler(fp, offset);
            break;
        case LC_DYLD_INFO_ONLY:
            dyld_info_command_handler(fp, offset);
            break;
        default:
            break;
    }
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *machoFilePath = @"/Users/xx/Documents/Qiubai/GitHub/MachOExploration/HelloWorld/HelloWorld";
        FILE *fp = fopen(machoFilePath.UTF8String, "r");
        // 获取魔数
        uint32_t *magic = load_bytes(fp, 0, sizeof(uint32_t));
        NSLog(@"%X",*magic);
        free(magic);
        // 加载 Header
        struct mach_header_64 *header = load_header_64(fp);
        uint32_t ncmds = header->ncmds;
        free(header);
        
        // 加载 Load Commands
        uint32_t lc_offset = sizeof(struct mach_header_64);
        for (NSInteger i = 0; i != ncmds; ++i) {
            struct load_command *lc_base = load_bytes(fp,lc_offset,sizeof(struct load_command));
            load_commands_handler(lc_base,fp, lc_offset);
            lc_offset += lc_base->cmdsize;
            free(lc_base);
        }
    }
    return 0;
}
