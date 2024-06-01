import argparse
import json
import subprocess
import re
import os

def is_ip_address(line):
    # 简单的IP地址正则表达式
    ip_pattern = re.compile(r"^(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?$")
    return ip_pattern.match(line) is not None

def main(input_file):
    # 读取输入文件内容并忽略以#开头的行
    with open(input_file, 'r') as file:
        lines = [line.strip() for line in file if not line.strip().startswith('#')]

    if not lines:
        print(f"输入文件 {input_file} 为空或全是注释。")
        return

    # 检测第一行是IP还是域名
    first_line = lines[0]
    if is_ip_address(first_line):
        key = "ip_cidr"
    else:
        key = "domain_suffix"

    # 构建所需的JSON结构
    data = {
        "version": 1,
        "rules": [
            {
                key: lines
            }
        ]
    }

    # 将数据写入输出文件
    json_output_file = input_file.replace('.txt', '.json')
    with open(json_output_file, 'w') as json_file:
        json.dump(data, json_file, indent=4)

    print(f"转换完成，数据已写入 {json_output_file} 文件中。")

    # 确定输出文件名
    srs_output_file = input_file.replace('.txt', '.srs')

    # 调用 sing-box 命令
    sing_box_command = ["./sing-box", "rule-set", "compile", "--output", srs_output_file, json_output_file]
    try:
        subprocess.run(sing_box_command, check=True)
        print(f"成功生成 {srs_output_file} 文件。")
    except subprocess.CalledProcessError as e:
        print(f"调用 sing-box 失败: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Convert list to JSON format and compile to .srs.')
    parser.add_argument('input_file', type=str, help='输入文件路径，必须以 .txt 结尾')

    args = parser.parse_args()

    # 检查输入文件是否以 .txt 结尾
    if not args.input_file.endswith('.txt'):
        print("错误：输入文件必须以 .txt 结尾")
    else:
        main(args.input_file)
