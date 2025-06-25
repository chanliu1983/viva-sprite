# VivaSprite

VivaSprite 是一个用于创建和编辑像素艺术动画的 macOS 应用程序。它结合了像素艺术编辑器和骨骼动画系统，让用户能够轻松创建精美的 2D 动画。

## 主要功能

### 像素艺术编辑器

- **绘图工具**
  - 画笔工具：自定义大小的画笔进行绘制
  - 橡皮擦：清除不需要的像素
  - 颜色选择器：从画布上选取颜色
  - 平移工具：移动画布视图

- **颜色系统**
  - 内置调色板
  - 当前颜色显示
  - 支持 RGB 颜色

- **画布操作**
  - 灵活的缩放控制
  - 自动缩放以适应窗口
  - 支持导入现有图片
  - 可调整画布大小

### 骨骼动画系统

- **骨骼编辑**
  - 创建和编辑骨骼结构
  - 支持多个关节和骨骼
  - 可自定义骨骼名称和属性

- **高级动画功能**
  - 实现 FABRIK（Forward And Backward Reaching Inverse Kinematics）算法
  - 支持关节角度约束
  - 固定关节功能
  - 保持骨骼长度不变

- **像素艺术绑定**
  - 将像素艺术绑定到骨骼
  - 支持调整像素艺术的缩放和旋转
  - 可设置绘制顺序

## 技术特点

- **现代化架构**
  - 使用 Swift 开发
  - 基于 Cocoa 框架
  - 采用 SIMD 进行高效的数学计算

- **数据持久化**
  - 支持保存和加载项目
  - 使用可编码（Codable）协议序列化数据
  - Base64 编码存储像素数据

- **性能优化**
  - 高效的渲染系统
  - 优化的 IK 求解器
  - 智能的内存管理

## 系统要求

- macOS 10.15 或更高版本
- 支持 Metal 的 Mac 设备

## 开发者说明

### 项目结构

- `PixelArtEditorWindow.swift`: 像素艺术编辑器的主窗口
- `PixelArtCanvasView.swift`: 像素艺术画布视图
- `SkeletalSystem.swift`: 骨骼动画系统的核心实现
- `ColorPalette.swift`: 颜色选择器组件
- `ToolManager.swift`: 工具状态管理

### 核心类

- `Skeleton`: 管理整个骨骼结构
- `Joint`: 表示骨骼系统中的关节
- `Bone`: 连接关节的骨骼
- `PixelArtData`: 存储像素艺术数据
- `IKSolver`: 实现 IK（反向运动学）算法

### 数据结构

```swift
class Skeleton {
    var joints: [Joint]
    var bones: [Bone]
    var pixelArts: [PixelArtData]
}

class Joint {
    var position: simd_float2
    var rotation: Float
    var isFixed: Bool
    var connectedBones: [Bone]
}

class Bone {
    let startJoint: Joint
    let endJoint: Joint
    var pixelArt: PixelArtData?
    var pixelArtScale: Float
    var pixelArtRotation: Float
}
```

## 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 许可证

[许可证类型] - 查看 LICENSE 文件了解更多信息

## 致谢

感谢所有为这个项目做出贡献的开发者。