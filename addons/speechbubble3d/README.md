
# SpeechBubble3D
Godot addon for custom Node3D that shows a speech bubble.


## Installation

1. Download the plugin and place the `speechbubble3d` folder inside the `addons` folder of your Godot project.
2. Enable the plugin in **Project Settings** > **Plugins**.

## Usage

1. Add a `SpeechBubble3D` node as a child of the 3D node of the talker.
2. Move it above the head of the talker.
3. Call **say_text(text)** method to show the text in a speech bubble.

## Properties:

- **wrap_size (float)**
Maximum width of speech bubble in pixels. Text wraps to multiple lines if length exceeds `wrap_size`. [default=300.0]

- **text_speed (float)**
Speed that letters appear. If 0.0, text is shown all at once. [default=0.02]
- **text_color (Color)**
Color of text. [default=Color(0.0, 0.0, 0.0)]
- **text_font (Font)**
Font used for text. If null uses the font included in addon. [default=null]

- **text_color (Color)**
Color of text. [default=Color(0.0, 0.0, 0.0)]

- **text_size (float)**
Size of text. [default=16]

- **layer (int)**
Layer of bubble - higher number displayed in front of lower. Bubbles aren't sorted by distance to speaker. To make a closer speaker's bubble appear in front of others, set `layer` to a higher number. [default=1]

## Methods:

- **say_text(text:String, life:float = 0.0)**
Shows speech bubble containing `text`. If `life` = 0.0, the bubble remains until it is closed. If `life`  > 0.0, the bubble automatically closes `life` seconds after the text finishes displaying.

- **close_bubble()**
Hides the speech bubble.

- **showing_text()**
Returns true if speech bubble visible.

## Contact

For questions or suggestions, contact [tamortgithub@gmail.com](mailto:tamortgithub@gmail.com).

