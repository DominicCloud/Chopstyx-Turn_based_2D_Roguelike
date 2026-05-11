## Log messages for game-state events (win, loss, welcome screen, Charon AI).
## None of these require placeholders unless noted.
class_name LogGameMessages
extends LogTemplate

@export_multiline var victory: String = "[b][color=#00E5FF]⚔ VICTORY! You have bested the Ferryman! ⚔[/color][/b]"
@export_multiline var defeat: String = "[b][color=#FF3399]💀 DEFEAT! Charon claims another soul... 💀[/color][/b]"
@export_multiline var welcome_title: String = "[b][color=#FFD700]⚔ ChopStyx - Duel of the Ferryman ⚔[/color][/b]"
@export_multiline var welcome_subtitle: String = "[color=#AAAAAA]Eliminate all of Charon's hands to escape the Underworld![/color]"
@export_multiline var restart_subtitle: String = "[color=#AAAAAA]A new challenger approaches the River Styx...[/color]"
@export_multiline var charon_stunned: String = "[color=#888888]🗿 Charon's hands remain petrified — turn skipped![/color]"
