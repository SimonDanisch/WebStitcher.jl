using WebStitcher, FileIO
n = 5 # correspondencs (>= 4)
# Else open a GUI to let you choose correspondences

im1 = load(joinpath(@__DIR__, "law1.jpg"))
im2 = load(joinpath(@__DIR__, "law2.jpg"))
(XY1, XY2), plot = WebStitcher.getcorrespondences(im1, im2, n)
#save(pointsPath, "XY1", "XY2")
plot # need to display this in a cell

include("projective_transform.jl")
H21 = projective_transform(XY2[], XY1[]) # 2 --> 1
## Stitch images from perspective 1

I1 = [
    ImageStitcher(copy(im1), eye(3)),
    ImageStitcher(copy(im2), H21)
]

# order = "natural": closet (to chosen persepctive) displayed on top
# order = "reverse": farthest displayed on top
imS1 = stitchImages(I1, order = "reverse")
