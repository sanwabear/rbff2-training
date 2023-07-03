local on_frame_func ={
    repeat_ptn = "%{[^%}]+%}x%d+,?"
}
local act_txt = "{2(1)2}x3(1)3(1)"
local a, b = string.find(act_txt, on_frame_func.repeat_ptn)
print(string.format("%s %s %s", a, b, string.sub(act_txt, a, b)))