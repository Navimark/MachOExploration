# !/usr/local/bin/python3
# -*- coding: utf-8 -*-
#

__doc__ = """

"""
# pip3 install Pillow --user
from PIL import Image, ImageFilter, ImageDraw, ImageFont
import sys
import imghdr
from pathlib import Path
import typing
import plistlib
from typing import List
import subprocess
from pbxproj import PBXNativeTarget
from pbxproj import XcodeProject
import os


class AddVersionInfo():

    def __init__(self, img_folder: str, version: str, branch_name: str, commit_id: str):
        self.img_folder = img_folder
        self.version = version
        self.branch_name = branch_name
        self.commit_id = commit_id

    @classmethod
    def __add_img_blur(cls, img, blur_rect: tuple):
        img = img.convert("RGB")
        img.load()
        mask = Image.new('L', img.size, 0)
        draw = ImageDraw.Draw(mask)
        # 左上角点，右下角点
        draw.rectangle([blur_rect[:2], img.size], fill=255)
        height = img.size[0]
        blurred = img.filter(ImageFilter.GaussianBlur(height * 0.06))
        img.paste(blurred, mask=mask)
        return img

    @classmethod
    def __add_img_txt(cls, img, draw, txt: str, top_margins: List[int]):
        top_margin = top_margins[0]
        myFont = ImageFont.truetype("SFNSMono.ttf", int(0.14 * img.size[0]))
        txt_size = draw.textsize(txt, font=myFont)
        versionTxtO = ((img.size[0] - txt_size[0]) / 2, top_margin)
        draw.text(versionTxtO, txt, fill="black", font=myFont)
        top_margins[0] = top_margin + txt_size[1]
        return img

    def add_single_img(self, img_path: str):
        img = Image.open(img_path)
        blur_rect = (0, int(img.size[1]*0.5),
                     int(img.size[0]), int(img.size[1]*0.5))
        img = AddVersionInfo.__add_img_blur(img, blur_rect)

        draw = ImageDraw.Draw(img)
        last_top_margin = img.size[1]*0.5 + 2
        for txt in [self.version, self.branch_name, self.commit_id]:
            margin_wrapper = [last_top_margin]
            img = AddVersionInfo.__add_img_txt(
                img, draw, txt, top_margins=margin_wrapper)
            last_top_margin = margin_wrapper[0]
        img.save(img_path)

    def add_version_info(self):
        print("版本号:{}".format(self.version))
        print("分支:{}".format(self.branch_name))
        print("上次提交:{}".format(self.commit_id))
        for root, _, file_list in os.walk(self.img_folder):
            for file in file_list:
                full_path = os.path.join(root, file)
                if os.path.isfile(full_path) and imghdr.what(full_path) in ['png']:
                    self.add_single_img(full_path)


def exe_command(list):
    result = subprocess.run(list, stdout=subprocess.PIPE)
    return result.stdout.decode("utf-8").strip('\n')


class Getoutofloop(Exception):
    pass


class ProjectInfo():
    def __init__(self, pbproject_path: str, target_name: str):
        self.pbproject_path = pbproject_path
        self.target_name = target_name
        self.project = XcodeProject.load(pbproject_path)
        self.build_configs = self.project.objects.get_configurations_on_targets(
            target_name=target_name)
        self.release_build_config = [
            b for b in self.build_configs if b.name == 'Release'][-1]

    def __find_icon_img_folder(self, icon_img_name: str, target_folder: str):
        icon_img_path = ''
        try:
            for root, folder_list, _ in os.walk(target_folder):
                for file in folder_list:
                    if file == icon_img_name:
                        icon_img_path = os.path.join(root, file)
                        raise Getoutofloop()
        except Getoutofloop:
            pass

        return icon_img_path

    def __project_main_path(self):
        return os.path.dirname(os.path.split(self.pbproject_path)[0])

    def get_icon_image_folder(self):
        name = self.release_build_config.buildSettings['ASSETCATALOG_COMPILER_APPICON_NAME']
        if name:
            search_folder = self.__project_main_path()
            icon_img_name = name+'.appiconset'
            return self.__find_icon_img_folder(icon_img_name, search_folder)
        print('FATAL: AppICON 路径未找到')
        return ''

    def __get_info_plist_path(self):
        info_plist_path = self.release_build_config.buildSettings['INFOPLIST_FILE']
        if info_plist_path:
            xcode_placeholder_path = '$(SRCROOT)'  # 可能在路径中并没有
            info_plist_path = info_plist_path.replace(
                xcode_placeholder_path, '')
            info_plist_path = info_plist_path if info_plist_path[0] != '/' else info_plist_path[1:]
            info_plist_path = os.path.join(
                self.__project_main_path(), info_plist_path)
        return info_plist_path

    def get_version_info(self):
        # 先从 project 获取，如果失败(失败定义：不全是 数字 和 '.' 组成)，从 plist 获取
        def valid_version(main_version: str):
            """
            如果由 . 和 数字组成，就是合法的；如果全部由数字组成，也是合法的
            """
            return ('.' in main_version and main_version.replace('.', '').isdigit()) or main_version.isdigit()
        # 主包的主工程版本号读取
        main_version = self.release_build_config.buildSettings['MARKETING_VERSION']
        if main_version and valid_version(main_version):
            plist_path = self.__get_info_plist_path()
            print("转向从 plist 读取版本号: {}".format(plist_path))
            plist = None
            with open(plist_path, 'rb') as rbf:
                plist = plistlib.load(rbf)
            if plist:
                return main_version+'.'+plist['CFBundleVersion'].split('.')[-1]
        return ''

    def get_git_branch_name(self):
        name = exe_command(['git', 'symbolic-ref', '--short', '-q', 'HEAD']).split('/')[-1]
        if len(name) == 0 or len(name.replace(' ','')) == 0:
            return os.environ.get('GIT_BRANCH','').split('/')[-1]
        return name

    def get_git_last_cmt_id(self):
        return exe_command(['git', 'rev-parse', '--short', 'HEAD'])


if __name__ == '__main__':

    pathes = sys.argv[1:] if len(sys.argv) > 1 else []
    if len(pathes) != 2:
        print("参数个数错误")
    else:
        pbproj_filepath = os.path.abspath(pathes[0])
        target_name = pathes[1]
        if not Path(pbproj_filepath).exists():
            print("FATAL:{} 不存在".format(pbproj_filepath))
            exit(1)
        pf = ProjectInfo(pbproj_filepath, target_name)
        avi = AddVersionInfo(pf.get_icon_image_folder(),
                             pf.get_version_info(),
                             pf.get_git_branch_name(),
                             pf.get_git_last_cmt_id())
        avi.add_version_info()
