#if defined _countdown_timer_included_
	#endinput
#endif
#define _countdown_timer_included_

methodmap CountdownTimerPtr
{
	public void Start(float duration) {
		this.m_duration = duration;
		this.m_timestamp = GetGameTime() + duration;
	}
	public bool HasStarted() {
		return this.m_timestamp > 0.0;
	}
	public bool IsElasped() {
		return GetGameTime() >= this.m_timestamp;
	}
	public float GetElapsedTime() {
		return GetGameTime() - this.m_timestamp + this.m_duration;
	}
	public float GetRemainingTime() {
		return (this.m_timestamp - GetGameTime());
	}
	property float m_duration {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(4), NumberType_Int32); }
		public set(float duration) { StoreToAddress(view_as<Address>(this) + view_as<Address>(4), duration, NumberType_Int32, false); }
	}
	property float m_timestamp {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(8), NumberType_Int32); }
		public set(float duration) { StoreToAddress(view_as<Address>(this) + view_as<Address>(8), duration, NumberType_Int32, false); }
	}
}
