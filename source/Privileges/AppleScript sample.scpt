FasdUAS 1.101.10   ��   ��    k             l      ��  ��   �� 
	A sample script to demonstrate the AppleScript capabilities of Privileges.

	Copyright 2024-2025 SAP SE. All rights reserved.

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at
 
	http://www.apache.org/licenses/LICENSE-2.0
 
	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
     � 	 	*   
 	 A   s a m p l e   s c r i p t   t o   d e m o n s t r a t e   t h e   A p p l e S c r i p t   c a p a b i l i t i e s   o f   P r i v i l e g e s . 
 
 	 C o p y r i g h t   2 0 2 4 - 2 0 2 5   S A P   S E .   A l l   r i g h t s   r e s e r v e d . 
 
 	 L i c e n s e d   u n d e r   t h e   A p a c h e   L i c e n s e ,   V e r s i o n   2 . 0   ( t h e   " L i c e n s e " ) ; 
 	 y o u   m a y   n o t   u s e   t h i s   f i l e   e x c e p t   i n   c o m p l i a n c e   w i t h   t h e   L i c e n s e . 
 	 Y o u   m a y   o b t a i n   a   c o p y   o f   t h e   L i c e n s e   a t 
   
 	 h t t p : / / w w w . a p a c h e . o r g / l i c e n s e s / L I C E N S E - 2 . 0 
   
 	 U n l e s s   r e q u i r e d   b y   a p p l i c a b l e   l a w   o r   a g r e e d   t o   i n   w r i t i n g ,   s o f t w a r e 
 	 d i s t r i b u t e d   u n d e r   t h e   L i c e n s e   i s   d i s t r i b u t e d   o n   a n   " A S   I S "   B A S I S , 
 	 W I T H O U T   W A R R A N T I E S   O R   C O N D I T I O N S   O F   A N Y   K I N D ,   e i t h e r   e x p r e s s   o r   i m p l i e d . 
 	 S e e   t h e   L i c e n s e   f o r   t h e   s p e c i f i c   l a n g u a g e   g o v e r n i n g   p e r m i s s i o n s   a n d 
 	 l i m i t a t i o n s   u n d e r   t h e   L i c e n s e . 
   
  
 l     ��������  ��  ��        l     ����  O         k           r        I   	������
�� .PAagpExpnull��� ��� null��  ��    o      ���� 0 remainingtime remainingTime   ��  r        I   ������
�� .PAagpStanull��� ��� null��  ��    o      ���� 0 isadmin isAdmin��    m       �                                                                                      @ alis    |  Macintosh HD               �_gBD ����PrivilegesAgent.app                                            �����m�0        ����  
 cu             MacOS   A/:Applications:Privileges.app:Contents:MacOS:PrivilegesAgent.app/   (  P r i v i l e g e s A g e n t . a p p    M a c i n t o s h   H D  >Applications/Privileges.app/Contents/MacOS/PrivilegesAgent.app  / ��  ��  ��        l     ��������  ��  ��        l    ����  r         m     ! ! � " "  Y o u   h a v e     o      ���� 0 
dialogtext 
dialogText��  ��     # $ # l     ��������  ��  ��   $  % & % l   X '���� ' Z    X ( )�� * ( l    +���� + o    ���� 0 isadmin isAdmin��  ��   ) k    P , ,  - . - l   ��������  ��  ��   .  / 0 / r    " 1 2 1 b      3 4 3 o    ���� 0 
dialogtext 
dialogText 4 m     5 5 � 6 6 2 a d m i n i s t r a t o r   p r i v i l e g e s . 2 o      ���� 0 
dialogtext 
dialogText 0  7 8 7 l  # #��������  ��  ��   8  9 : 9 Z   # N ; <�� = ; l  # & >���� > ?   # & ? @ ? o   # $���� 0 remainingtime remainingTime @ m   $ %����  ��  ��   < k   ) F A A  B C B r   ) 0 D E D b   ) . F G F b   ) , H I H o   ) *���� 0 
dialogtext 
dialogText I m   * + J J � K K H 
 A d m i n i s t r a t o r   p r i v i l e g e s   e x p i r e   i n   G o   , -���� 0 remainingtime remainingTime E o      ���� 0 
dialogtext 
dialogText C  L M L l  1 1��������  ��  ��   M  N O N Z   1 D P Q�� R P l  1 4 S���� S =   1 4 T U T o   1 2���� 0 remainingtime remainingTime U m   2 3���� ��  ��   Q r   7 < V W V b   7 : X Y X o   7 8���� 0 
dialogtext 
dialogText Y m   8 9 Z Z � [ [    m i n u t e . W o      ���� 0 
dialogtext 
dialogText��   R r   ? D \ ] \ b   ? B ^ _ ^ o   ? @���� 0 
dialogtext 
dialogText _ m   @ A ` ` � a a    m i n u t e s . ] o      ���� 0 
dialogtext 
dialogText O  b�� b l  E E��������  ��  ��  ��  ��   = r   I N c d c b   I L e f e o   I J���� 0 
dialogtext 
dialogText f m   J K g g � h h N 
 A d m i n i s t r a t o r   p r i v i l e g e s   d o n ' t   e x p i r e . d o      ���� 0 
dialogtext 
dialogText :  i�� i l  O O��������  ��  ��  ��  ��   * r   S X j k j b   S V l m l o   S T���� 0 
dialogtext 
dialogText m m   T U n n � o o 2 s t a n d a r d   u s e r   p r i v i l e g e s . k o      ���� 0 
dialogtext 
dialogText��  ��   &  p q p l     ��������  ��  ��   q  r s r l  Y j t���� t I  Y j�� u v
�� .sysodlogaskr        TEXT u o   Y Z���� 0 
dialogtext 
dialogText v �� w x
�� 
disp w m   [ \����  x �� y z
�� 
btns y J   ] ` { {  |�� | m   ] ^ } } � ~ ~  O K��   z �� ��
�� 
dflt  m   c d���� ��  ��  ��   s  � � � l     ��������  ��  ��   �  ��� � l     ��������  ��  ��  ��       �� � ���   � ��
�� .aevtoappnull  �   � **** � �� ����� � ���
�� .aevtoappnull  �   � **** � k     j � �   � �   � �  % � �  r����  ��  ��   �   �  �������� !�� 5 J Z ` g n���� }������
�� .PAagpExpnull��� ��� null�� 0 remainingtime remainingTime
�� .PAagpStanull��� ��� null�� 0 isadmin isAdmin�� 0 
dialogtext 
dialogText
�� 
disp
�� 
btns
�� 
dflt�� 
�� .sysodlogaskr        TEXT�� k� *j E�O*j E�UO�E�O� 8��%E�O�j "��%�%E�O�k  
��%E�Y ��%E�OPY ��%E�OPY ��%E�O��k��kva ka  ascr  ��ޭ