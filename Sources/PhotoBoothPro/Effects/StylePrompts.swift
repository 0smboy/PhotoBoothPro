import Foundation

enum StylePrompts {
    static let ghibli = """
    Transform this portrait into Studio Ghibli animation style. Soft watercolor textures, \
    warm hand-painted backgrounds, gentle cel-shaded lines, dreamy pastel palette. \
    Preserve the subject's identity, face shape, hairstyle, and clothing silhouette. \
    Keep the composition and framing the same.
    """

    static let anime = """
    Transform this portrait into a modern Japanese anime illustration. Crisp line art, \
    vibrant saturated colors, cel-shaded lighting, expressive large eyes while keeping \
    the subject clearly recognizable. Preserve identity, hairstyle, and clothing. \
    Keep the composition the same.
    """

    static let oilPainting = """
    Transform this portrait into a classical oil painting in the style of Rembrandt \
    or John Singer Sargent. Visible impasto brushstrokes, rich chiaroscuro lighting, \
    deep saturated colors, museum-quality finish. Preserve the subject's likeness, \
    pose, and composition faithfully.
    """

    static let pixelArt = """
    Transform this portrait into 16-bit pixel art reminiscent of SNES-era JRPGs. \
    Limited 32-color palette, clean pixel edges, chunky pixels visible, dithering for \
    gradients. Preserve the subject's identity, hair color, and clothing colors. \
    Keep the composition the same.
    """
}
