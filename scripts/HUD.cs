using Godot;

public class HUD : CanvasLayer
{
	private ProgressBar _healthProgress;
	private Label _healthLabel;
	private Label _livesLabel;
	private Label _moneyLabel;
	private Player _player;

	public override void _Ready()
	{
		var healthPanel = GetNodeOrNull<Control>("HealthPanel");
		if (healthPanel == null) return;
		
		_healthProgress = healthPanel.GetNodeOrNull<ProgressBar>("HealthProgress");
		_healthLabel = healthPanel.GetNodeOrNull<Label>("HealthLabel");
		_livesLabel = healthPanel.GetNodeOrNull<Label>("LivesLabel");
		_moneyLabel = healthPanel.GetNodeOrNull<Label>("MoneyLabel");
		
		if (_healthProgress == null || _healthLabel == null) return;
		
		SetupProgressBarStyle();
		_healthProgress.MinValue = 0;
		_healthProgress.MaxValue = 100;
		_healthProgress.Value = 100;
		_healthProgress.PercentVisible = false;
		
		CallDeferred(nameof(FindPlayerAndConnect));
	}
	
	private void FindPlayerAndConnect()
	{
		_player = GetTree().GetRoot().FindNode("Player", true, false) as Player;
		
		if (_player == null)
		{
			_player = GetTree().GetRoot().FindNode("PlayerTank", true, false) as Player;
		}
		
		if (_player != null)
		{
			if (!_player.IsConnected(nameof(Player.HealthChanged), this, nameof(OnHealthChanged)))
			{
				_player.Connect(nameof(Player.HealthChanged), this, nameof(OnHealthChanged));
			}
			
			if (!_player.IsConnected(nameof(Player.LivesChanged), this, nameof(OnLivesChanged)))
			{
				_player.Connect(nameof(Player.LivesChanged), this, nameof(OnLivesChanged));
			}
			
			if (!_player.IsConnected(nameof(Player.MoneyChanged), this, nameof(OnMoneyChanged)))
			{
				_player.Connect(nameof(Player.MoneyChanged), this, nameof(OnMoneyChanged));
			}
			
			int currentHealth = _player.GetCurrentHealth();
			int maxHealth = _player.GetMaxHealth();
			int currentLives = _player.GetLives();
			int currentMoney = _player.GetMoney();
			
			int displayHealth = Mathf.Max(0, currentHealth);
			
			_healthProgress.MaxValue = maxHealth;
			_healthProgress.Value = displayHealth;
			_healthLabel.Text = $"{displayHealth}/{maxHealth}";
			
			if (_livesLabel != null)
			{
				_livesLabel.Text = $"Жизни: {currentLives}";
			}
			
			if (_moneyLabel != null)
			{
				_moneyLabel.Text = $"💰 {currentMoney}";
			}
			
			UpdateHealthColor(displayHealth, maxHealth);
		}
		else
		{
			GetTree().CreateTimer(0.5f).Connect("timeout", this, nameof(FindPlayerAndConnect));
		}
	}
	
	private void SetupProgressBarStyle()
	{
		if (_healthProgress == null) return;
		
		var backgroundStyle = new StyleBoxFlat();
		backgroundStyle.BgColor = new Color(0.1f, 0.1f, 0.1f);
		backgroundStyle.BorderWidthBottom = 2;
		backgroundStyle.BorderWidthTop = 2;
		backgroundStyle.BorderWidthLeft = 2;
		backgroundStyle.BorderWidthRight = 2;
		backgroundStyle.BorderColor = new Color(0.3f, 0.3f, 0.3f);
		backgroundStyle.CornerRadiusBottomLeft = 5;
		backgroundStyle.CornerRadiusBottomRight = 5;
		backgroundStyle.CornerRadiusTopLeft = 5;
		backgroundStyle.CornerRadiusTopRight = 5;

		var progressStyle = new StyleBoxFlat();
		progressStyle.BgColor = new Color(0.2f, 0.8f, 0.2f);
		progressStyle.CornerRadiusBottomLeft = 5;
		progressStyle.CornerRadiusBottomRight = 5;
		progressStyle.CornerRadiusTopLeft = 5;
		progressStyle.CornerRadiusTopRight = 5;
		
		_healthProgress.AddStyleboxOverride("under", backgroundStyle);
		_healthProgress.AddStyleboxOverride("fg", progressStyle);
	}

	private void OnHealthChanged(int currentHealth, int maxHealth)
	{
		if (_healthProgress == null || _healthLabel == null) return;
		
		int displayHealth = Mathf.Max(0, currentHealth);
		
		_healthProgress.Value = displayHealth;
		_healthLabel.Text = $"{displayHealth}/{maxHealth}";
		UpdateHealthColor(displayHealth, maxHealth);
	}
	
	private void OnLivesChanged(int currentLives)
	{
		if (_livesLabel == null) return;
		_livesLabel.Text = $"Жизни: {currentLives}";
	}
	
	private void OnMoneyChanged(int currentMoney)
	{
		if (_moneyLabel == null) return;
		_moneyLabel.Text = $"💰 {currentMoney}";
	}
	
	private void UpdateHealthColor(int currentHealth, int maxHealth)
	{
		float percent = (float)currentHealth / maxHealth;
		var style = _healthProgress.GetStylebox("fg");
		if (style is StyleBoxFlat flatStyle)
		{
			if (percent <= 0.3f)
				flatStyle.BgColor = new Color(1f, 0.2f, 0.2f);
			else if (percent <= 0.6f)
				flatStyle.BgColor = new Color(1f, 0.8f, 0.2f);
			else
				flatStyle.BgColor = new Color(0.2f, 0.8f, 0.2f);
			
			_healthProgress.AddStyleboxOverride("fg", flatStyle);
		}
	}
}
