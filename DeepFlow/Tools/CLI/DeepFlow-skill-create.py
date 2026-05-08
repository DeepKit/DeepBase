#!/usr/bin/env python3
"""
DeepFlow Skill 脚手架 CLI 工具
============================
快速创建符合 DeepFlow 规范的 Skill 项目骨架。

使用方法：
    python DeepFlow-skill-create.py <skill_name> [options]

示例：
    python DeepFlow-skill-create.py text_summarize
    python DeepFlow-skill-create.py image_analyzer --type python --author "张三"
    python DeepFlow-skill-create.py data_export --type delphi

作者：鲁班（开发者）
日期：2025-12-04
"""

import os
import sys
import argparse
import json
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, Optional

# ============== 模板定义 ==============

PYTHON_SKILL_TEMPLATE = '''"""
{skill_name} Skill
==================
{description}

作者：{author}
创建日期：{created_date}
版本：{version}
"""

import logging
from typing import Dict, Any, Optional
from dataclasses import dataclass

logger = logging.getLogger("DeepFlow.skill.{skill_name_lower}")


@dataclass
class {skill_class_name}Input:
    """Skill 输入参数"""
    # TODO: 定义输入参数
    text: str
    options: Optional[Dict[str, Any]] = None


@dataclass  
class {skill_class_name}Output:
    """Skill 输出结果"""
    # TODO: 定义输出参数
    result: str
    metadata: Optional[Dict[str, Any]] = None


class {skill_class_name}Skill:
    """
    {description}
    
    使用示例：
        skill = {skill_class_name}Skill()
        result = skill.execute({skill_class_name}Input(text="hello"))
    """
    
    # Skill 元数据
    NAME = "{skill_name_lower}"
    VERSION = "{version}"
    DESCRIPTION = "{description}"
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        """
        初始化 Skill
        
        Args:
            config: 可选的配置参数
        """
        self.config = config or {{}}
        self._validate_config()
        logger.info(f"{{self.NAME}} v{{self.VERSION}} initialized")
    
    def _validate_config(self):
        """验证配置"""
        # TODO: 添加配置验证逻辑
        pass
    
    def execute(self, input_data: {skill_class_name}Input) -> {skill_class_name}Output:
        """
        执行 Skill
        
        Args:
            input_data: 输入参数
            
        Returns:
            {skill_class_name}Output: 执行结果
            
        Raises:
            ValueError: 输入参数无效
            RuntimeError: 执行过程出错
        """
        logger.info(f"Executing {{self.NAME}}")
        
        try:
            # 1. 输入验证
            self._validate_input(input_data)
            
            # 2. 执行核心逻辑
            result = self._process(input_data)
            
            # 3. 构造输出
            output = {skill_class_name}Output(
                result=result,
                metadata={{
                    "skill_name": self.NAME,
                    "skill_version": self.VERSION,
                    "processed_at": datetime.now().isoformat()
                }}
            )
            
            logger.info(f"{{self.NAME}} executed successfully")
            return output
            
        except Exception as e:
            logger.error(f"{{self.NAME}} execution failed: {{e}}")
            raise
    
    def _validate_input(self, input_data: {skill_class_name}Input):
        """验证输入"""
        if not input_data.text:
            raise ValueError("text is required")
        # TODO: 添加更多验证逻辑
    
    def _process(self, input_data: {skill_class_name}Input) -> str:
        """
        核心处理逻辑
        
        TODO: 实现具体的处理逻辑
        """
        # 示例实现
        return f"Processed: {{input_data.text}}"


# FastAPI 路由注册（可选）
def register_routes(app):
    """注册 FastAPI 路由"""
    from fastapi import HTTPException
    from pydantic import BaseModel
    
    class ExecuteRequest(BaseModel):
        text: str
        options: Optional[Dict[str, Any]] = None
    
    skill = {skill_class_name}Skill()
    
    @app.post("/skills/{skill_name_lower}/execute")
    async def execute(request: ExecuteRequest):
        try:
            input_data = {skill_class_name}Input(
                text=request.text,
                options=request.options
            )
            result = skill.execute(input_data)
            return {{
                "success": True,
                "data": {{
                    "result": result.result,
                    "metadata": result.metadata
                }}
            }}
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))


# 命令行入口（可选）
if __name__ == "__main__":
    import argparse
    from datetime import datetime
    
    parser = argparse.ArgumentParser(description="{description}")
    parser.add_argument("text", help="Input text")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    
    args = parser.parse_args()
    
    skill = {skill_class_name}Skill()
    input_data = {skill_class_name}Input(text=args.text)
    result = skill.execute(input_data)
    
    if args.json:
        import json
        print(json.dumps({{
            "result": result.result,
            "metadata": result.metadata
        }}, ensure_ascii=False, indent=2))
    else:
        print(result.result)
'''

PYTHON_TEST_TEMPLATE = '''"""
{skill_name} Skill 测试
"""

import pytest
from {skill_name_lower} import {skill_class_name}Skill, {skill_class_name}Input, {skill_class_name}Output


class Test{skill_class_name}Skill:
    """测试 {skill_class_name}Skill"""
    
    def setup_method(self):
        """测试前准备"""
        self.skill = {skill_class_name}Skill()
    
    def test_execute_success(self):
        """测试正常执行"""
        input_data = {skill_class_name}Input(text="hello world")
        result = self.skill.execute(input_data)
        
        assert isinstance(result, {skill_class_name}Output)
        assert result.result is not None
        assert result.metadata is not None
        assert result.metadata["skill_name"] == "{skill_name_lower}"
    
    def test_execute_empty_input(self):
        """测试空输入"""
        input_data = {skill_class_name}Input(text="")
        
        with pytest.raises(ValueError):
            self.skill.execute(input_data)
    
    def test_execute_with_options(self):
        """测试带选项的执行"""
        input_data = {skill_class_name}Input(
            text="test",
            options={{"key": "value"}}
        )
        result = self.skill.execute(input_data)
        
        assert result.result is not None
    
    def test_skill_metadata(self):
        """测试 Skill 元数据"""
        assert self.skill.NAME == "{skill_name_lower}"
        assert self.skill.VERSION == "{version}"
        assert self.skill.DESCRIPTION is not None


class Test{skill_class_name}Integration:
    """集成测试"""
    
    @pytest.mark.integration
    def test_end_to_end(self):
        """端到端测试"""
        skill = {skill_class_name}Skill()
        
        # 模拟真实场景
        input_data = {skill_class_name}Input(
            text="This is a test document for integration testing."
        )
        
        result = skill.execute(input_data)
        
        assert result.result is not None
        assert len(result.result) > 0
'''

SKILL_MANIFEST_TEMPLATE = '''{
  "name": "{skill_name_lower}",
  "version": "{version}",
  "description": "{description}",
  "author": "{author}",
  "created_at": "{created_date}",
  "type": "{skill_type}",
  "entry_point": "{entry_point}",
  "dependencies": [],
  "input_schema": {
    "type": "object",
    "properties": {
      "text": {
        "type": "string",
        "description": "输入文本"
      },
      "options": {
        "type": "object",
        "description": "可选配置"
      }
    },
    "required": ["text"]
  },
  "output_schema": {
    "type": "object",
    "properties": {
      "result": {
        "type": "string",
        "description": "处理结果"
      },
      "metadata": {
        "type": "object",
        "description": "元数据"
      }
    }
  },
  "config_schema": {
    "type": "object",
    "properties": {}
  },
  "permissions": {
    "data_access": "L1",
    "network": false,
    "file_system": false
  },
  "tags": []
}
'''

DELPHI_SKILL_TEMPLATE = '''unit DeepFlow.Skill.{skill_class_name};

{{
  {skill_name} Skill
  ==================
  {description}
  
  作者：{author}
  创建日期：{created_date}
  版本：{version}
}}

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  DeepFlow.Skill.Base;

type
  T{skill_class_name}Input = class(TSkillInput)
  private
    FText: string;
    FOptions: TJSONObject;
  public
    property Text: string read FText write FText;
    property Options: TJSONObject read FOptions write FOptions;
    
    procedure FromJSON(AJSON: TJSONObject); override;
    function ToJSON: TJSONObject; override;
  end;

  T{skill_class_name}Output = class(TSkillOutput)
  private
    FResult: string;
    FMetadata: TJSONObject;
  public
    property Result: string read FResult write FResult;
    property Metadata: TJSONObject read FMetadata write FMetadata;
    
    function ToJSON: TJSONObject; override;
  end;

  T{skill_class_name}Skill = class(TSkillBase)
  public
    const NAME = '{skill_name_lower}';
    const VERSION = '{version}';
  public
    constructor Create(AConfig: TJSONObject = nil); override;
    function Execute(AInput: TSkillInput): TSkillOutput; override;
    
    class function GetName: string; override;
    class function GetVersion: string; override;
    class function GetDescription: string; override;
  protected
    procedure ValidateInput(AInput: T{skill_class_name}Input);
    function Process(AInput: T{skill_class_name}Input): string;
  end;

implementation

{{ T{skill_class_name}Input }}

procedure T{skill_class_name}Input.FromJSON(AJSON: TJSONObject);
begin
  inherited;
  FText := AJSON.GetValue<string>('text', '');
  if AJSON.TryGetValue<TJSONObject>('options', FOptions) then
    FOptions := FOptions.Clone as TJSONObject
  else
    FOptions := nil;
end;

function T{skill_class_name}Input.ToJSON: TJSONObject;
begin
  Result := inherited;
  Result.AddPair('text', FText);
  if Assigned(FOptions) then
    Result.AddPair('options', FOptions.Clone as TJSONObject);
end;

{{ T{skill_class_name}Output }}

function T{skill_class_name}Output.ToJSON: TJSONObject;
begin
  Result := inherited;
  Result.AddPair('result', FResult);
  if Assigned(FMetadata) then
    Result.AddPair('metadata', FMetadata.Clone as TJSONObject);
end;

{{ T{skill_class_name}Skill }}

constructor T{skill_class_name}Skill.Create(AConfig: TJSONObject);
begin
  inherited Create(AConfig);
  // TODO: 初始化逻辑
end;

class function T{skill_class_name}Skill.GetName: string;
begin
  Result := NAME;
end;

class function T{skill_class_name}Skill.GetVersion: string;
begin
  Result := VERSION;
end;

class function T{skill_class_name}Skill.GetDescription: string;
begin
  Result := '{description}';
end;

function T{skill_class_name}Skill.Execute(AInput: TSkillInput): TSkillOutput;
var
  Input: T{skill_class_name}Input;
  Output: T{skill_class_name}Output;
  ProcessedResult: string;
begin
  Input := AInput as T{skill_class_name}Input;
  
  // 1. 验证输入
  ValidateInput(Input);
  
  // 2. 执行处理
  ProcessedResult := Process(Input);
  
  // 3. 构造输出
  Output := T{skill_class_name}Output.Create;
  Output.Result := ProcessedResult;
  Output.Metadata := TJSONObject.Create;
  Output.Metadata.AddPair('skill_name', NAME);
  Output.Metadata.AddPair('skill_version', VERSION);
  Output.Metadata.AddPair('processed_at', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now));
  
  Result := Output;
end;

procedure T{skill_class_name}Skill.ValidateInput(AInput: T{skill_class_name}Input);
begin
  if AInput.Text.IsEmpty then
    raise EArgumentException.Create('text is required');
  // TODO: 添加更多验证逻辑
end;

function T{skill_class_name}Skill.Process(AInput: T{skill_class_name}Input): string;
begin
  // TODO: 实现具体的处理逻辑
  Result := 'Processed: ' + AInput.Text;
end;

end.
'''

README_TEMPLATE = '''# {skill_name} Skill

{description}

## 概述

| 属性 | 值 |
|------|-----|
| 名称 | `{skill_name_lower}` |
| 版本 | `{version}` |
| 类型 | `{skill_type}` |
| 作者 | {author} |
| 创建日期 | {created_date} |

## 安装

### Python Skill

```bash
cd skills/{skill_name_lower}
pip install -r requirements.txt
```

### Delphi Skill

将 `DeepFlow.Skill.{skill_class_name}.pas` 添加到项目中。

## 使用

### Python

```python
from {skill_name_lower} import {skill_class_name}Skill, {skill_class_name}Input

skill = {skill_class_name}Skill()
result = skill.execute({skill_class_name}Input(text="hello world"))
print(result.result)
```

### Delphi

```pascal
uses DeepFlow.Skill.{skill_class_name};

var
  Skill: T{skill_class_name}Skill;
  Input: T{skill_class_name}Input;
  Output: T{skill_class_name}Output;
begin
  Skill := T{skill_class_name}Skill.Create;
  try
    Input := T{skill_class_name}Input.Create;
    Input.Text := 'hello world';
    
    Output := Skill.Execute(Input) as T{skill_class_name}Output;
    WriteLn(Output.Result);
  finally
    Skill.Free;
  end;
end;
```

### HTTP API

```bash
curl -X POST http://localhost:8765/skills/{skill_name_lower}/execute \\
  -H "Content-Type: application/json" \\
  -d '{{"text": "hello world"}}'
```

## 输入输出

### 输入 Schema

```json
{{
  "type": "object",
  "properties": {{
    "text": {{
      "type": "string",
      "description": "输入文本"
    }},
    "options": {{
      "type": "object",
      "description": "可选配置"
    }}
  }},
  "required": ["text"]
}}
```

### 输出 Schema

```json
{{
  "type": "object",
  "properties": {{
    "result": {{
      "type": "string",
      "description": "处理结果"
    }},
    "metadata": {{
      "type": "object",
      "description": "元数据"
    }}
  }}
}}
```

## 测试

```bash
pytest test_{skill_name_lower}.py -v
```

## 变更日志

### {version} ({created_date})
- 初始版本
'''

REQUIREMENTS_TEMPLATE = '''# {skill_name} Skill Dependencies
# 基础依赖
typing-extensions>=4.0.0

# 根据需要添加其他依赖
# numpy>=1.20.0
# pandas>=1.3.0
# requests>=2.25.0
'''

# ============== CLI 主逻辑 ==============

def to_pascal_case(name: str) -> str:
    """转换为 PascalCase"""
    parts = name.replace('-', '_').split('_')
    return ''.join(word.capitalize() for word in parts)


def to_snake_case(name: str) -> str:
    """转换为 snake_case"""
    return name.replace('-', '_').lower()


def create_skill(
    skill_name: str,
    skill_type: str = "python",
    description: str = "",
    author: str = "DeepFlow Team",
    version: str = "1.0.0",
    output_dir: Optional[str] = None
) -> str:
    """
    创建 Skill 项目骨架
    
    Args:
        skill_name: Skill 名称
        skill_type: 类型 (python/delphi/both)
        description: 描述
        author: 作者
        version: 版本
        output_dir: 输出目录
        
    Returns:
        创建的目录路径
    """
    # 标准化名称
    skill_name_lower = to_snake_case(skill_name)
    skill_class_name = to_pascal_case(skill_name)
    created_date = datetime.now().strftime("%Y-%m-%d")
    
    # 默认描述
    if not description:
        description = f"{skill_class_name} Skill - TODO: 添加描述"
    
    # 确定输出目录
    if output_dir:
        base_dir = Path(output_dir) / skill_name_lower
    else:
        base_dir = Path.cwd() / "skills" / skill_name_lower
    
    # 创建目录结构
    base_dir.mkdir(parents=True, exist_ok=True)
    
    # 模板变量
    template_vars = {
        "skill_name": skill_name,
        "skill_name_lower": skill_name_lower,
        "skill_class_name": skill_class_name,
        "description": description,
        "author": author,
        "version": version,
        "created_date": created_date,
        "skill_type": skill_type,
        "entry_point": f"{skill_name_lower}.py" if skill_type == "python" else f"DeepFlow.Skill.{skill_class_name}.pas"
    }
    
    # 生成文件
    files_created = []
    
    # README
    readme_path = base_dir / "README.md"
    readme_path.write_text(README_TEMPLATE.format(**template_vars), encoding='utf-8')
    files_created.append(str(readme_path))
    
    # Manifest
    manifest_path = base_dir / "skill.json"
    manifest_path.write_text(SKILL_MANIFEST_TEMPLATE.format(**template_vars), encoding='utf-8')
    files_created.append(str(manifest_path))
    
    # Python Skill
    if skill_type in ("python", "both"):
        python_path = base_dir / f"{skill_name_lower}.py"
        python_path.write_text(PYTHON_SKILL_TEMPLATE.format(**template_vars), encoding='utf-8')
        files_created.append(str(python_path))
        
        # 测试文件
        test_path = base_dir / f"test_{skill_name_lower}.py"
        test_path.write_text(PYTHON_TEST_TEMPLATE.format(**template_vars), encoding='utf-8')
        files_created.append(str(test_path))
        
        # requirements.txt
        req_path = base_dir / "requirements.txt"
        req_path.write_text(REQUIREMENTS_TEMPLATE.format(**template_vars), encoding='utf-8')
        files_created.append(str(req_path))
    
    # Delphi Skill
    if skill_type in ("delphi", "both"):
        delphi_path = base_dir / f"DeepFlow.Skill.{skill_class_name}.pas"
        delphi_path.write_text(DELPHI_SKILL_TEMPLATE.format(**template_vars), encoding='utf-8')
        files_created.append(str(delphi_path))
    
    return str(base_dir), files_created


def main():
    parser = argparse.ArgumentParser(
        description="DeepFlow Skill 脚手架工具 - 快速创建符合规范的 Skill 项目",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  %(prog)s text_summarize
  %(prog)s image_analyzer --type python --author "张三"
  %(prog)s data_export --type delphi --description "数据导出 Skill"
  %(prog)s translator --type both --output ./my_skills
        """
    )
    
    parser.add_argument(
        "skill_name",
        help="Skill 名称（支持 snake_case 或 kebab-case）"
    )
    
    parser.add_argument(
        "--type", "-t",
        choices=["python", "delphi", "both"],
        default="python",
        help="Skill 类型 (默认: python)"
    )
    
    parser.add_argument(
        "--description", "-d",
        default="",
        help="Skill 描述"
    )
    
    parser.add_argument(
        "--author", "-a",
        default="DeepFlow Team",
        help="作者 (默认: DeepFlow Team)"
    )
    
    parser.add_argument(
        "--version", "-v",
        default="1.0.0",
        help="版本号 (默认: 1.0.0)"
    )
    
    parser.add_argument(
        "--output", "-o",
        default=None,
        help="输出目录 (默认: ./skills/<skill_name>)"
    )
    
    parser.add_argument(
        "--quiet", "-q",
        action="store_true",
        help="静默模式，只输出创建的目录路径"
    )
    
    args = parser.parse_args()
    
    try:
        output_path, files = create_skill(
            skill_name=args.skill_name,
            skill_type=args.type,
            description=args.description,
            author=args.author,
            version=args.version,
            output_dir=args.output
        )
        
        if args.quiet:
            print(output_path)
        else:
            print(f"""
╔══════════════════════════════════════════════════════════════╗
║           DeepFlow Skill 创建成功！                           ║
╠══════════════════════════════════════════════════════════════╣
║  Skill 名称: {args.skill_name:<45} ║
║  类型: {args.type:<50} ║
║  输出目录: {output_path:<43} ║
╠══════════════════════════════════════════════════════════════╣
║  创建的文件:                                                 ║""")
            for f in files:
                rel_path = os.path.relpath(f, output_path)
                print(f"║    - {rel_path:<53} ║")
            print("""╠══════════════════════════════════════════════════════════════╣
║  下一步:                                                     ║
║    1. 编辑 skill.json 完善元数据                             ║
║    2. 实现 _process() 方法中的核心逻辑                       ║
║    3. 运行测试: pytest test_*.py -v                          ║
║    4. 注册到 DeepFlow: DeepFlow skill register <path>          ║
╚══════════════════════════════════════════════════════════════╝
            """)
            
    except Exception as e:
        print(f"错误: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
