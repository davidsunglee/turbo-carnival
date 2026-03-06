#if os(iOS)

@MainActor
public final class TouchInputProvider: InputProvider {
    public init() {}

    public func poll() -> PlayerInput {
        // Stub — dynamic-origin virtual joystick to be implemented later
        PlayerInput()
    }
}

#endif
