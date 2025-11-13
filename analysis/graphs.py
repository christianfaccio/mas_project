import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns

# Set style for better-looking plots
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (12, 8)
plt.rcParams['font.size'] = 11

df = pd.read_csv('results/1.csv')

# Calculate derived metrics
df['survival_rate'] = (df['tot_saved_people'] / df['tot_people']) * 100
df['spectator_survival_rate'] = (df['tot_spectators_saved'] / df['nb_of_spectators']) * 100
df['worker_survival_rate'] = (df['tot_workers_saved'] / df['nb_of_workers']) * 100
df['leader_survival_rate'] = (df['tot_leaders_saved'] / (df['nb_of_spectators'] * df['leader_frac'])) * 100
df['follower_survival_rate'] = (df['tot_followers_saved'] / (df['nb_of_spectators'] * df['follower_frac'])) * 100
df['panic_victim_rate'] = (df['tot_panic_victims'] / df['tot_victims']) * 100

# Print summary statistics
print("="*60)
print("EVACUATION SIMULATION ANALYSIS")
print("="*60)
print(f"\nDataset: {len(df)} simulation runs")
print(f"Total people per simulation: {df['tot_people'].iloc[0]}")
print(f"Workers/Spectators ratio: {df['workers_over_spectators'].iloc[0]}")
print(f"Number of spectators: {df['nb_of_spectators'].iloc[0]}")
print(f"Number of workers: {df['nb_of_workers'].iloc[0]}")

print("\n" + "="*60)
print("OVERALL SURVIVAL STATISTICS")
print("="*60)
print(f"Mean survival rate: {df['survival_rate'].mean():.2f}% (±{df['survival_rate'].std():.2f}%)")
print(f"Range: {df['survival_rate'].min():.2f}% - {df['survival_rate'].max():.2f}%")
print(f"\nMean victims: {df['tot_victims'].mean():.1f} (±{df['tot_victims'].std():.1f})")
print(f"Mean saved: {df['tot_saved_people'].mean():.1f} (±{df['tot_saved_people'].std():.1f})")

print("\n" + "="*60)
print("SURVIVAL RATES BY ROLE")
print("="*60)
print(f"Spectators: {df['spectator_survival_rate'].mean():.2f}% (±{df['spectator_survival_rate'].std():.2f}%)")
print(f"Workers: {df['worker_survival_rate'].mean():.2f}% (±{df['worker_survival_rate'].std():.2f}%)")
print(f"Leaders: {df['leader_survival_rate'].mean():.2f}% (±{df['leader_survival_rate'].std():.2f}%)")
print(f"Followers: {df['follower_survival_rate'].mean():.2f}% (±{df['follower_survival_rate'].std():.2f}%)")

print("\n" + "="*60)
print("PANIC ANALYSIS")
print("="*60)
print(f"Mean panic victims: {df['tot_panic_victims'].mean():.1f} (±{df['tot_panic_victims'].std():.1f})")
print(f"Panic victims as % of total victims: {df['panic_victim_rate'].mean():.2f}%")

# Create visualizations
fig = plt.figure(figsize=(16, 12))

# 1. Overall survival rate distribution across runs
ax1 = plt.subplot(2, 3, 1)
runs = range(1, len(df) + 1)
plt.bar(runs, df['survival_rate'], color='steelblue', alpha=0.7, edgecolor='black')
plt.axhline(y=df['survival_rate'].mean(), color='red', linestyle='--', linewidth=2, label=f'Mean: {df["survival_rate"].mean():.1f}%')
plt.xlabel('Simulation Run', fontweight='bold')
plt.ylabel('Survival Rate (%)', fontweight='bold')
plt.title('Overall Survival Rate Variability\nAcross Simulation Runs', fontweight='bold', fontsize=12)
plt.xticks(runs)
plt.ylim([0, 100])
plt.legend()
plt.grid(axis='y', alpha=0.3)

# 2. Survival rates by role (mean with std)
ax2 = plt.subplot(2, 3, 2)
roles = ['Spectators', 'Workers', 'Leaders', 'Followers']
means = [
    df['spectator_survival_rate'].mean(),
    df['worker_survival_rate'].mean(),
    df['leader_survival_rate'].mean(),
    df['follower_survival_rate'].mean()
]
stds = [
    df['spectator_survival_rate'].std(),
    df['worker_survival_rate'].std(),
    df['leader_survival_rate'].std(),
    df['follower_survival_rate'].std()
]
colors = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#FFA07A']
bars = plt.bar(roles, means, yerr=stds, color=colors, alpha=0.7, edgecolor='black', capsize=5, linewidth=1.5)
plt.ylabel('Survival Rate (%)', fontweight='bold')
plt.title('Survival Rates by Agent Role\n(Mean ± Std Dev)', fontweight='bold', fontsize=12)
plt.ylim([0, 100])
plt.grid(axis='y', alpha=0.3)

# Add value labels on bars
for i, (bar, mean, std) in enumerate(zip(bars, means, stds)):
    height = bar.get_height()
    plt.text(bar.get_x() + bar.get_width()/2., height + std + 2,
             f'{mean:.1f}%',
             ha='center', va='bottom', fontweight='bold', fontsize=10)

# 3. Victims vs Saved scatter plot
ax3 = plt.subplot(2, 3, 3)
plt.scatter(df['tot_victims'], df['tot_saved_people'], s=150, alpha=0.6, c=runs, cmap='viridis', edgecolors='black', linewidth=1.5)
plt.xlabel('Total Victims', fontweight='bold')
plt.ylabel('Total Saved', fontweight='bold')
plt.title('Victims vs Saved People\n(Colored by Run Number)', fontweight='bold', fontsize=12)
plt.colorbar(label='Run Number')
plt.grid(alpha=0.3)

# Add diagonal reference line
max_val = max(df['tot_victims'].max(), df['tot_saved_people'].max())
plt.plot([0, max_val], [500, 500-max_val], 'r--', alpha=0.5, linewidth=2, label='Victims + Saved = 500')
plt.legend()

# 4. Victim breakdown by category
ax4 = plt.subplot(2, 3, 4)
victim_categories = ['Spectators', 'Workers', 'Leaders', 'Followers', 'Panic']
victim_means = [
    df['tot_spectators_victims'].mean(),
    df['tot_workers_victims'].mean(),
    df['tot_leaders_victims'].mean(),
    df['tot_followers_victims'].mean(),
    df['tot_panic_victims'].mean()
]
victim_stds = [
    df['tot_spectators_victims'].std(),
    df['tot_workers_victims'].std(),
    df['tot_leaders_victims'].std(),
    df['tot_followers_victims'].std(),
    df['tot_panic_victims'].std()
]
colors_victims = ['#E74C3C', '#3498DB', '#2ECC71', '#F39C12', '#9B59B6']
bars = plt.bar(victim_categories, victim_means, yerr=victim_stds, color=colors_victims, alpha=0.7, edgecolor='black', capsize=5, linewidth=1.5)
plt.ylabel('Number of Victims', fontweight='bold')
plt.title('Victim Distribution by Category\n(Mean ± Std Dev)', fontweight='bold', fontsize=12)
plt.xticks(rotation=15, ha='right')
plt.grid(axis='y', alpha=0.3)

# Add value labels
for bar, mean in zip(bars, victim_means):
    height = bar.get_height()
    plt.text(bar.get_x() + bar.get_width()/2., height + 2,
             f'{mean:.1f}',
             ha='center', va='bottom', fontweight='bold', fontsize=9)

# 5. Comparison: Spectators vs Workers survival
ax5 = plt.subplot(2, 3, 5)
x = np.arange(len(df))
width = 0.35
bars1 = plt.bar(x - width/2, df['spectator_survival_rate'], width, label='Spectators', color='#FF6B6B', alpha=0.7, edgecolor='black')
bars2 = plt.bar(x + width/2, df['worker_survival_rate'], width, label='Workers', color='#4ECDC4', alpha=0.7, edgecolor='black')
plt.xlabel('Simulation Run', fontweight='bold')
plt.ylabel('Survival Rate (%)', fontweight='bold')
plt.title('Spectators vs Workers Survival Rates\nAcross Runs', fontweight='bold', fontsize=12)
plt.xticks(x, [f'{i+1}' for i in range(len(df))])
plt.ylim([0, 100])
plt.legend()
plt.grid(axis='y', alpha=0.3)

# 6. Leaders vs Followers survival
ax6 = plt.subplot(2, 3, 6)
bars1 = plt.bar(x - width/2, df['leader_survival_rate'], width, label='Leaders', color='#45B7D1', alpha=0.7, edgecolor='black')
bars2 = plt.bar(x + width/2, df['follower_survival_rate'], width, label='Followers', color='#FFA07A', alpha=0.7, edgecolor='black')
plt.xlabel('Simulation Run', fontweight='bold')
plt.ylabel('Survival Rate (%)', fontweight='bold')
plt.title('Leaders vs Followers Survival Rates\nAcross Runs', fontweight='bold', fontsize=12)
plt.xticks(x, [f'{i+1}' for i in range(len(df))])
plt.ylim([0, 100])
plt.legend()
plt.grid(axis='y', alpha=0.3)

plt.tight_layout()
plt.savefig('output/evacuation_analysis_overview.png', dpi=300, bbox_inches='tight')
print("\n✓ Saved: evacuation_analysis_overview.png")

# Create additional detailed analysis plots
fig2 = plt.figure(figsize=(16, 10))

# 7. Panic victims correlation with total victims
ax7 = plt.subplot(2, 3, 1)
plt.scatter(df['tot_victims'], df['tot_panic_victims'], s=150, alpha=0.6, c='crimson', edgecolors='black', linewidth=1.5)
z = np.polyfit(df['tot_victims'], df['tot_panic_victims'], 1)
p = np.poly1d(z)
plt.plot(df['tot_victims'], p(df['tot_victims']), "r--", alpha=0.8, linewidth=2, label=f'Trend line')
plt.xlabel('Total Victims', fontweight='bold')
plt.ylabel('Panic Victims', fontweight='bold')
plt.title('Panic Victims vs Total Victims\n(Correlation Analysis)', fontweight='bold', fontsize=12)
plt.legend()
plt.grid(alpha=0.3)

# Add correlation coefficient
corr = df[['tot_victims', 'tot_panic_victims']].corr().iloc[0, 1]
plt.text(0.05, 0.95, f'Correlation: {corr:.3f}', transform=ax7.transAxes, 
         fontsize=11, fontweight='bold', verticalalignment='top',
         bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

# 8. Survival rate by victim count
ax8 = plt.subplot(2, 3, 2)
plt.scatter(df['tot_victims'], df['survival_rate'], s=150, alpha=0.6, c='forestgreen', edgecolors='black', linewidth=1.5)
z = np.polyfit(df['tot_victims'], df['survival_rate'], 1)
p = np.poly1d(z)
plt.plot(df['tot_victims'], p(df['tot_victims']), "r--", alpha=0.8, linewidth=2, label='Trend line')
plt.xlabel('Total Victims', fontweight='bold')
plt.ylabel('Overall Survival Rate (%)', fontweight='bold')
plt.title('Survival Rate vs Number of Victims\n(Inverse Relationship)', fontweight='bold', fontsize=12)
plt.legend()
plt.grid(alpha=0.3)

corr = df[['tot_victims', 'survival_rate']].corr().iloc[0, 1]
plt.text(0.05, 0.95, f'Correlation: {corr:.3f}', transform=ax8.transAxes, 
         fontsize=11, fontweight='bold', verticalalignment='top',
         bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

# 9. Box plot of survival rates by role
ax9 = plt.subplot(2, 3, 3)
survival_data = [
    df['spectator_survival_rate'],
    df['worker_survival_rate'],
    df['leader_survival_rate'],
    df['follower_survival_rate']
]
bp = plt.boxplot(survival_data, labels=roles, patch_artist=True, notch=True, 
                 widths=0.6, showmeans=True, meanline=True)

for patch, color in zip(bp['boxes'], colors):
    patch.set_facecolor(color)
    patch.set_alpha(0.6)

plt.ylabel('Survival Rate (%)', fontweight='bold')
plt.title('Survival Rate Distribution by Role\n(Box Plot with Median & Mean)', fontweight='bold', fontsize=12)
plt.grid(axis='y', alpha=0.3)
plt.ylim([0, 100])

# 10. Stacked bar chart of outcomes
ax10 = plt.subplot(2, 3, 4)
categories = ['Spectators', 'Workers']
saved = [df['tot_spectators_saved'].mean(), df['tot_workers_saved'].mean()]
victims = [df['tot_spectators_victims'].mean(), df['tot_workers_victims'].mean()]

x_pos = np.arange(len(categories))
p1 = plt.bar(x_pos, saved, color='#2ECC71', alpha=0.7, edgecolor='black', linewidth=1.5, label='Saved')
p2 = plt.bar(x_pos, victims, bottom=saved, color='#E74C3C', alpha=0.7, edgecolor='black', linewidth=1.5, label='Victims')

plt.ylabel('Number of People', fontweight='bold')
plt.title('Average Outcomes: Saved vs Victims\n(Spectators vs Workers)', fontweight='bold', fontsize=12)
plt.xticks(x_pos, categories)
plt.legend(loc='upper right')
plt.grid(axis='y', alpha=0.3)

# Add percentage labels
for i, (s, v) in enumerate(zip(saved, victims)):
    total = s + v
    saved_pct = (s / total) * 100
    victim_pct = (v / total) * 100
    plt.text(i, s/2, f'{saved_pct:.1f}%', ha='center', va='center', fontweight='bold', fontsize=11, color='white')
    plt.text(i, s + v/2, f'{victim_pct:.1f}%', ha='center', va='center', fontweight='bold', fontsize=11, color='white')

# 11. Variability analysis
ax11 = plt.subplot(2, 3, 5)
metrics = ['Overall', 'Spectators', 'Workers', 'Leaders', 'Followers']
coeffs_of_variation = [
    (df['survival_rate'].std() / df['survival_rate'].mean()) * 100,
    (df['spectator_survival_rate'].std() / df['spectator_survival_rate'].mean()) * 100,
    (df['worker_survival_rate'].std() / df['worker_survival_rate'].mean()) * 100,
    (df['leader_survival_rate'].std() / df['leader_survival_rate'].mean()) * 100,
    (df['follower_survival_rate'].std() / df['follower_survival_rate'].mean()) * 100
]
colors_var = ['#34495E', '#FF6B6B', '#4ECDC4', '#45B7D1', '#FFA07A']
bars = plt.bar(metrics, coeffs_of_variation, color=colors_var, alpha=0.7, edgecolor='black', linewidth=1.5)
plt.ylabel('Coefficient of Variation (%)', fontweight='bold')
plt.title('Survival Rate Variability by Category\n(Lower = More Consistent)', fontweight='bold', fontsize=12)
plt.xticks(rotation=15, ha='right')
plt.grid(axis='y', alpha=0.3)

for bar, cv in zip(bars, coeffs_of_variation):
    height = bar.get_height()
    plt.text(bar.get_x() + bar.get_width()/2., height + 0.5,
             f'{cv:.1f}%',
             ha='center', va='bottom', fontweight='bold', fontsize=9)

# 12. Extreme outcomes comparison
ax12 = plt.subplot(2, 3, 6)
best_run = df['survival_rate'].idxmax()
worst_run = df['survival_rate'].idxmin()

categories_extreme = ['Spectators\nVictims', 'Workers\nVictims', 'Leaders\nVictims', 
                     'Followers\nVictims', 'Panic\nVictims']
best_values = [
    df.loc[best_run, 'tot_spectators_victims'],
    df.loc[best_run, 'tot_workers_victims'],
    df.loc[best_run, 'tot_leaders_victims'],
    df.loc[best_run, 'tot_followers_victims'],
    df.loc[best_run, 'tot_panic_victims']
]
worst_values = [
    df.loc[worst_run, 'tot_spectators_victims'],
    df.loc[worst_run, 'tot_workers_victims'],
    df.loc[worst_run, 'tot_leaders_victims'],
    df.loc[worst_run, 'tot_followers_victims'],
    df.loc[worst_run, 'tot_panic_victims']
]

x_pos = np.arange(len(categories_extreme))
width = 0.35
bars1 = plt.bar(x_pos - width/2, best_values, width, label=f'Best Run ({df.loc[best_run, "survival_rate"]:.1f}%)', 
               color='#2ECC71', alpha=0.7, edgecolor='black', linewidth=1.5)
bars2 = plt.bar(x_pos + width/2, worst_values, width, label=f'Worst Run ({df.loc[worst_run, "survival_rate"]:.1f}%)', 
               color='#E74C3C', alpha=0.7, edgecolor='black', linewidth=1.5)

plt.ylabel('Number of Victims', fontweight='bold')
plt.title('Best vs Worst Run Comparison\n(Victim Distribution)', fontweight='bold', fontsize=12)
plt.xticks(x_pos, categories_extreme, fontsize=9)
plt.legend()
plt.grid(axis='y', alpha=0.3)

plt.tight_layout()
plt.savefig('output/evacuation_analysis_detailed.png', dpi=300, bbox_inches='tight')
print("✓ Saved: evacuation_analysis_detailed.png")

print("\n" + "="*60)
print("ANALYSIS COMPLETE - FILES SAVED")
print("="*60)
